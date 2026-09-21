package com.pgplatform.onboarding.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record OwnerKycProfileRequest(
        @NotBlank String legalName,
        @NotBlank @Pattern(regexp = "^[A-Za-z0-9]{4}$") String panLastFour,
        @NotBlank @Pattern(regexp = "^[0-9]{4}$") String aadhaarLastFour
) {
}
