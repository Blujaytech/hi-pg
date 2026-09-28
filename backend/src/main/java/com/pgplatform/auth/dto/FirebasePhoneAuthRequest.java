package com.pgplatform.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record FirebasePhoneAuthRequest(
        @NotBlank String idToken,
        @Size(max = 120) String fullName
) {
}
