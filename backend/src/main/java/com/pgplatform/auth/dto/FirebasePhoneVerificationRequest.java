package com.pgplatform.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record FirebasePhoneVerificationRequest(
        @NotBlank String idToken
) {
}
