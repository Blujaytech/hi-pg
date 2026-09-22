package com.pgplatform.payment.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record DirectPaymentRejectRequest(
        @NotBlank @Size(max = 100) String idempotencyKey,
        @NotBlank @Size(max = 2000) String reason
) {
}
