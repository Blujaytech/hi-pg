package com.pgplatform.billing.dto;

import com.pgplatform.billing.PaymentMethod;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;

public record PaymentCreateRequest(
        @NotNull @DecimalMin("0.01") BigDecimal amountPaid,
        @NotNull LocalDate paidOn,
        @NotNull PaymentMethod method,
        String reference,
        String note
) {
}
