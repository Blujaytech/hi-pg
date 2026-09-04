package com.pgplatform.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record StudentOtpVerifyRequest(
        @NotBlank String phone,
        @NotBlank String code,
        String fullName
) {
}
