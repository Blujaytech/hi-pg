package com.pgplatform.onboarding.dto;

import jakarta.validation.constraints.NotBlank;

public record OwnerKycProfileRequest(
        @NotBlank String legalName
) {
}
