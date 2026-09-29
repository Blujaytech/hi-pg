package com.pgplatform.owner.dto;

import com.pgplatform.owner.*;

import java.time.Instant;
import java.util.UUID;

/** Admin-only response. It is the only PG DTO allowed to contain owner mobile. */
public record AdminPgListingResponse(
        UUID id,
        String name,
        String address,
        String city,
        String state,
        String pincode,
        Double latitude,
        Double longitude,
        String description,
        GenderPreference genderPreference,
        PgStatus status,
        PgClaimStatus claimStatus,
        PgVerificationStatus verificationStatus,
        boolean bookingEnabled,
        String ownerName,
        String ownerMobile,
        PgInvitationStatus invitationStatus,
        long interestCount,
        Instant createdAt
) { }
