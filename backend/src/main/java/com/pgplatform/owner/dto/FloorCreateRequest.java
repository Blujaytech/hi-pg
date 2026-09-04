package com.pgplatform.owner.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record FloorCreateRequest(
        @NotBlank String name,
        @NotNull Integer floorNumber
) {
}
