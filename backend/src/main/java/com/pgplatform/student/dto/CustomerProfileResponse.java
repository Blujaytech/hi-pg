package com.pgplatform.student.dto;

import com.pgplatform.student.CustomerProfile;
import com.pgplatform.student.IdentityType;

import java.time.Instant;
import java.util.UUID;

public record CustomerProfileResponse(
        UUID id,
        String fullName,
        String occupation,
        String phone,
        boolean phoneVerified,
        String permanentAddress,
        IdentityType identityType,
        String identityLast4,
        String termsAcceptedVersion,
        String privacyAcceptedVersion,
        String aadhaarConsentVersion,
        Instant updatedAt
) {
}
