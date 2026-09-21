package com.pgplatform.onboarding.dto;

import com.pgplatform.onboarding.OwnerKycStatus;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record OwnerKycReviewRequest(
        @NotNull OwnerKycStatus status,
        @Size(max = 100) String razorpayLinkedAccountId,
        @NotNull @Min(0) @Max(10000) Integer platformCommissionBps,
        @Size(max = 1000) String reviewNote
) {
}
