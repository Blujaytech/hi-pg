package com.pgplatform.owner.dto;

import com.pgplatform.owner.PaymentOnboardingStatus;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record PaymentOnboardingReviewRequest(
        @NotNull PaymentOnboardingStatus status,
        @Size(max = 100) String razorpayLinkedAccountId,
        @NotNull @Min(0) @Max(10000) Integer platformCommissionBps
) {
}
