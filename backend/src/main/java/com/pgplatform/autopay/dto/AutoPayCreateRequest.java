package com.pgplatform.autopay.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

public record AutoPayCreateRequest(@NotNull @Min(1) @Max(28) Integer dueDay) {
}
