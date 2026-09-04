package com.pgplatform.billing.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDate;

public record FeeCreateRequest(
        @NotNull @Min(1) @Max(12) Integer periodMonth,
        @NotNull @Min(2000) Integer periodYear,
        @NotNull @DecimalMin("0.01") BigDecimal amount,
        @NotNull LocalDate dueDate,
        String notes
) {
}
