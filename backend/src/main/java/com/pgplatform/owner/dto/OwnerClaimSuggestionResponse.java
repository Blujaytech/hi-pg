package com.pgplatform.owner.dto;

import com.pgplatform.owner.PgClaimStatus;
import com.pgplatform.owner.PgVerificationStatus;

import java.util.UUID;

public record OwnerClaimSuggestionResponse(
        UUID pgId,
        String name,
        String address,
        String city,
        PgClaimStatus claimStatus,
        PgVerificationStatus verificationStatus,
        long interestCount,
        boolean alreadyClaimedByYou
) { }
