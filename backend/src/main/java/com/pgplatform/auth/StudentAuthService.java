package com.pgplatform.auth;

import com.pgplatform.auth.dto.AuthResponse;
import com.pgplatform.auth.dto.StudentOtpRequestRequest;
import com.pgplatform.auth.dto.StudentOtpVerifyRequest;
import com.pgplatform.common.ConflictException;
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

    public StudentAuthService(UserRepository userRepository, OtpService otpService, TokenIssuer tokenIssuer) {
        this.userRepository = userRepository;
        this.otpService = otpService;
        this.tokenIssuer = tokenIssuer;
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

        User user = userRepository.findByPhoneAndDeletedAtIsNull(request.phone())
                .orElseGet(() -> createStudent(request));

        if (!user.isPhoneVerified()) {
            user.setPhoneVerified(true);
            userRepository.save(user);
        }

        return tokenIssuer.issueFor(user);
    }

    private User createStudent(StudentOtpVerifyRequest request) {
        User user = new User();
        user.setPhone(request.phone());
        user.setFullName(request.fullName() != null && !request.fullName().isBlank() ? request.fullName() : "Student");
        user.setRole(Role.STUDENT);
        user.setProvider(AuthProviderType.LOCAL);
        user.setPhoneVerified(true);
        return userRepository.save(user);
    }
}
