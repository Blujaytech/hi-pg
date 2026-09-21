package com.pgplatform.auth.web;

import com.pgplatform.auth.OwnerPhoneVerificationService;
import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.auth.dto.OwnerPhoneOtpRequest;
import com.pgplatform.auth.dto.OwnerPhoneOtpVerifyRequest;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/owner/profile/phone")
@PreAuthorize("hasRole('OWNER')")
public class OwnerPhoneVerificationController {
    private final OwnerPhoneVerificationService service;

    public OwnerPhoneVerificationController(OwnerPhoneVerificationService service) {
        this.service = service;
    }

    @PostMapping("/otp/request")
    public ResponseEntity<Void> request(@AuthenticationPrincipal UserPrincipal principal,
                                        @Valid @RequestBody OwnerPhoneOtpRequest request) {
        service.request(principal.getId(), request);
        return ResponseEntity.accepted().build();
    }

    @PostMapping("/otp/verify")
    public ResponseEntity<Void> verify(@AuthenticationPrincipal UserPrincipal principal,
                                       @Valid @RequestBody OwnerPhoneOtpVerifyRequest request) {
        service.verify(principal.getId(), request);
        return ResponseEntity.noContent().build();
    }
}
