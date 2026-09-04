package com.pgplatform.auth.web;

import com.pgplatform.auth.GoogleAuthService;
import com.pgplatform.auth.OwnerAuthService;
import com.pgplatform.auth.PasswordResetService;
import com.pgplatform.auth.SessionService;
import com.pgplatform.auth.StudentAuthService;
import com.pgplatform.auth.dto.AuthResponse;
import com.pgplatform.auth.dto.GoogleAuthRequest;
import com.pgplatform.auth.dto.OwnerLoginRequest;
import com.pgplatform.auth.dto.OwnerSignupRequest;
import com.pgplatform.auth.dto.PasswordResetConfirmRequest;
import com.pgplatform.auth.dto.PasswordResetRequestRequest;
import com.pgplatform.auth.dto.RefreshRequest;
import com.pgplatform.auth.dto.StudentOtpRequestRequest;
import com.pgplatform.auth.dto.StudentOtpVerifyRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final OwnerAuthService ownerAuthService;
    private final StudentAuthService studentAuthService;
    private final SessionService sessionService;
    private final PasswordResetService passwordResetService;
    private final GoogleAuthService googleAuthService;

    public AuthController(OwnerAuthService ownerAuthService, StudentAuthService studentAuthService,
                           SessionService sessionService, PasswordResetService passwordResetService,
                           GoogleAuthService googleAuthService) {
        this.ownerAuthService = ownerAuthService;
        this.studentAuthService = studentAuthService;
        this.sessionService = sessionService;
        this.passwordResetService = passwordResetService;
        this.googleAuthService = googleAuthService;
    }

    // --- Owner: email + password ---

    @PostMapping("/owner/signup")
    public ResponseEntity<AuthResponse> ownerSignup(@Valid @RequestBody OwnerSignupRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(ownerAuthService.signup(request));
    }

    @PostMapping("/owner/login")
    public AuthResponse ownerLogin(@Valid @RequestBody OwnerLoginRequest request) {
        return ownerAuthService.login(request);
    }

    // --- Student: phone + OTP ---

    @PostMapping("/student/otp/request")
    public ResponseEntity<Void> requestStudentOtp(@Valid @RequestBody StudentOtpRequestRequest request) {
        studentAuthService.requestOtp(request);
        return ResponseEntity.accepted().build();
    }

    @PostMapping("/student/otp/verify")
    public AuthResponse verifyStudentOtp(@Valid @RequestBody StudentOtpVerifyRequest request) {
        return studentAuthService.verifyOtp(request);
    }

    // --- Shared: refresh / logout ---

    @PostMapping("/refresh")
    public AuthResponse refresh(@Valid @RequestBody RefreshRequest request) {
        return sessionService.refresh(request.refreshToken());
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout(@Valid @RequestBody RefreshRequest request) {
        sessionService.logout(request.refreshToken());
        return ResponseEntity.noContent().build();
    }

    // --- Owner password reset ---

    @PostMapping("/owner/password-reset/request")
    public ResponseEntity<Map<String, String>> requestPasswordReset(@Valid @RequestBody PasswordResetRequestRequest request) {
        passwordResetService.requestReset(request.email());
        return ResponseEntity.ok(Map.of("message", "If that email exists, a reset link has been sent."));
    }

    @PostMapping("/owner/password-reset/confirm")
    public ResponseEntity<Void> confirmPasswordReset(@Valid @RequestBody PasswordResetConfirmRequest request) {
        passwordResetService.confirmReset(request.token(), request.newPassword());
        return ResponseEntity.noContent().build();
    }

    // --- Google OAuth (stub, both roles) ---

    @PostMapping("/google")
    public AuthResponse google(@Valid @RequestBody GoogleAuthRequest request) {
        return googleAuthService.authenticate(request);
    }
}
