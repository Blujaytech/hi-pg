package com.pgplatform.billing.dto;

import jakarta.validation.constraints.Future;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

public record FeeExtensionRequest(
        @NotNull @Future LocalDate newDueDate,
        @Size(max = 500) String note
) {
}
