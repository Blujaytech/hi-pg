package com.pgplatform.student.dto;

import com.pgplatform.student.IdentityType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CustomerProfileUpdateRequest(
        @NotBlank @Size(max = 255) String fullName,
        @NotBlank @Size(max = 120) String occupation,
        @Size(max = 2000) String permanentAddress,
        IdentityType identityType,
        @Size(min = 4, max = 4) String identityLast4,
        boolean acceptTerms,
        boolean acceptPrivacy,
        boolean acceptAadhaarConsent
) {
}
