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
        String locationUrl,
        String description,
        String photoUrl,
        GenderPreference genderPreference,
        PgStatus status,
        PgClaimStatus claimStatus,
        PgVerificationStatus verificationStatus,
        boolean bookingEnabled,
        String ownerName,
        String ownerMobile,
        PgInvitationStatus invitationStatus,
        OwnerSmsStatus invitationDeliveryStatus,
        String invitationFailureReason,
        long interestCount,
        Instant createdAt
) { }
