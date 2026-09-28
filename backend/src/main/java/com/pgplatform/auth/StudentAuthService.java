package com.pgplatform.auth;

import com.pgplatform.auth.dto.AuthResponse;
import com.pgplatform.auth.dto.StudentOtpRequestRequest;
import com.pgplatform.auth.dto.StudentOtpVerifyRequest;
import com.pgplatform.common.ConflictException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Student auth is phone + OTP first (India-appropriate, per the technical
 * plan). requestOtp works for both signup and login -- verifyOtp figures out
 * whether the phone is new (creates the user) or existing (logs them in).
 */
@Service
public class StudentAuthService {

    private final UserRepository userRepository;
    private final OtpService otpService;
    private final TokenIssuer tokenIssuer;
    private final FirebasePhoneIdentityVerifier firebaseIdentityVerifier;

    public StudentAuthService(UserRepository userRepository, OtpService otpService, TokenIssuer tokenIssuer,
                              FirebasePhoneIdentityVerifier firebaseIdentityVerifier) {
        this.userRepository = userRepository;
        this.otpService = otpService;
        this.tokenIssuer = tokenIssuer;
        this.firebaseIdentityVerifier = firebaseIdentityVerifier;
    }

    public void requestOtp(StudentOtpRequestRequest request) {
        otpService.requestOtp(request.phone(), OtpPurpose.STUDENT_SIGNUP_OR_LOGIN);
    }

    @Transactional
    public AuthResponse verifyOtp(StudentOtpVerifyRequest request) {
        boolean valid = otpService.verifyOtp(request.phone(), request.code(), OtpPurpose.STUDENT_SIGNUP_OR_LOGIN);
        if (!valid) {
            throw new ConflictException("Invalid or expired code");
        }

        return authenticateVerifiedPhone(request.phone(), request.fullName());
    }

    @Transactional
    public AuthResponse authenticateFirebasePhone(String idToken, String fullName) {
        FirebasePhoneIdentity identity = firebaseIdentityVerifier.verify(idToken);
        return authenticateVerifiedPhone(identity.phone(), fullName);
    }

    private AuthResponse authenticateVerifiedPhone(String verifiedPhone, String fullName) {
        String phone = normalizePhone(verifiedPhone);
        User user = findExistingPhoneUser(phone)
                .orElseGet(() -> createStudent(phone, fullName));

        // Same two guards GoogleAuthService applies to the other student login path.
        // Without them this endpoint issues a token carrying whatever role the phone's
        // account happens to have -- an owner/admin session from the student OTP flow --
        // and keeps working for accounts an admin has disabled.
        if (user.getRole() != Role.STUDENT) {
            throw new ConflictException("This number belongs to a PG owner. Use owner login instead.");
        }
        if (user.getStatus() == UserStatus.DISABLED) {
            throw new BadCredentialsException("Account disabled");
        }

        if (!user.isPhoneVerified()) {
            user.setPhoneVerified(true);
            userRepository.save(user);
        }

        return tokenIssuer.issueFor(user);
    }

    private java.util.Optional<User> findExistingPhoneUser(String e164Phone) {
        java.util.Optional<User> exact = userRepository.findByPhoneAndDeletedAtIsNull(e164Phone);
        if (exact.isPresent()) {
            return exact;
        }
        // Preserve accounts created by the earlier local-OTP build, which
        // stored Indian numbers as ten digits rather than E.164.
        if (e164Phone.startsWith("+91") && e164Phone.length() == 13) {
            return userRepository.findByPhoneAndDeletedAtIsNull(e164Phone.substring(3));
        }
        return java.util.Optional.empty();
    }

    private String normalizePhone(String phone) {
        String compact = phone == null ? "" : phone.replaceAll("[\\s()-]", "");
        if (compact.matches("\\d{10}")) {
            return "+91" + compact;
        }
        if (compact.matches("91\\d{10}")) {
            return "+" + compact;
        }
        if (!compact.matches("\\+[1-9]\\d{7,14}")) {
            throw new BadCredentialsException("Firebase returned an invalid phone number");
        }
        return compact;
    }

    private User createStudent(String phone, String fullName) {
        User user = new User();
        user.setPhone(phone);
        user.setFullName(fullName != null && !fullName.isBlank() ? fullName.trim() : "Student");
        user.setRole(Role.STUDENT);
        user.setProvider(AuthProviderType.LOCAL);
        user.setPhoneVerified(true);
        return userRepository.save(user);
    }
}
