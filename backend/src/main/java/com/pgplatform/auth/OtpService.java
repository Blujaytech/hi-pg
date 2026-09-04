package com.pgplatform.auth;

import com.pgplatform.common.ConflictException;
import com.pgplatform.notification.NotificationGateway;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

/**
 * §7 item 7 of the technical plan: SMS OTP is a cost-per-send abuse target,
 * so requestOtp enforces a per-phone-per-hour cap in addition to the normal
 * expiry/attempt-limit-on-verify OTP hygiene.
 */
@Service
public class OtpService {

    private static final int CODE_LENGTH = 6;
    private static final int MAX_VERIFY_ATTEMPTS = 5;

    private final OtpCodeRepository otpCodeRepository;
    private final JwtService jwtService; // reused for its hash() helper
    private final NotificationGateway notificationGateway;
    private final SecureRandom random = new SecureRandom();

    @Value("${app.otp.ttl-minutes:5}")
    private long ttlMinutes;

    @Value("${app.otp.max-attempts-per-hour:5}")
    private int maxRequestsPerHour;

    public OtpService(OtpCodeRepository otpCodeRepository, JwtService jwtService, NotificationGateway notificationGateway) {
        this.otpCodeRepository = otpCodeRepository;
        this.jwtService = jwtService;
        this.notificationGateway = notificationGateway;
    }

    public void requestOtp(String phone, OtpPurpose purpose) {
        Instant oneHourAgo = Instant.now().minus(1, ChronoUnit.HOURS);
        long recentCount = otpCodeRepository.findAllByPhoneAndPurposeAndCreatedAtAfter(phone, purpose, oneHourAgo).size();
        if (recentCount >= maxRequestsPerHour) {
            throw new ConflictException("Too many OTP requests for this number. Try again later.");
        }

        String code = String.valueOf(100000 + random.nextInt(900000)).substring(0, CODE_LENGTH);

        OtpCode otp = new OtpCode();
        otp.setPhone(phone);
        otp.setPurpose(purpose);
        otp.setCodeHash(jwtService.hash(code));
        otp.setExpiresAt(Instant.now().plus(ttlMinutes, ChronoUnit.MINUTES));
        otpCodeRepository.save(otp);

        notificationGateway.sendSms(phone, "Your PG Platform verification code is " + code + ". It expires in " + ttlMinutes + " minutes.");
    }

    public boolean verifyOtp(String phone, String code, OtpPurpose purpose) {
        OtpCode otp = otpCodeRepository
                .findFirstByPhoneAndPurposeAndConsumedFalseOrderByCreatedAtDesc(phone, purpose)
                .orElse(null);

        if (otp == null || otp.isExpired() || otp.getAttempts() >= MAX_VERIFY_ATTEMPTS) {
            return false;
        }

        otp.setAttempts(otp.getAttempts() + 1);

        boolean matches = otp.getCodeHash().equals(jwtService.hash(code));
        if (matches) {
            otp.setConsumed(true);
        }
        otpCodeRepository.save(otp);
        return matches;
    }
}
