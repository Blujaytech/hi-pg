package com.pgplatform.student.dto;

import com.pgplatform.student.IdentityType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import jakarta.validation.constraints.Pattern;

public record CustomerProfileUpdateRequest(
        @NotBlank @Size(max = 255) String fullName,
        @NotBlank @Size(max = 120) String occupation,
        @Size(max = 2000) String permanentAddress,
        @Size(max = 255) String guardianName,
        @Pattern(regexp = "^$|^\\+?[1-9][0-9]{9,14}$", message = "guardian phone must be a valid mobile number")
        String guardianPhone,
        IdentityType identityType,
        @Size(min = 4, max = 4) String identityLast4,
        boolean acceptTerms,
        boolean acceptPrivacy,
        boolean acceptAadhaarConsent
) {
    /** Compatibility for callers created before guardian contact fields were added. */
    public CustomerProfileUpdateRequest(String fullName, String occupation, String permanentAddress,
                                        IdentityType identityType, String identityLast4,
                                        boolean acceptTerms, boolean acceptPrivacy,
                                        boolean acceptAadhaarConsent) {
        this(fullName, occupation, permanentAddress, null, null, identityType, identityLast4,
                acceptTerms, acceptPrivacy, acceptAadhaarConsent);
    }
}
