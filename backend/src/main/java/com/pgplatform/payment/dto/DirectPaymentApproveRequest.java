package com.pgplatform.payment.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

public record DirectPaymentApproveRequest(
        @NotNull @DecimalMin(value = "0.01") @Digits(integer = 8, fraction = 2) BigDecimal amountReceived,
        @NotBlank @Size(max = 100) String idempotencyKey,
        @Size(max = 2000) String note
) {
}
