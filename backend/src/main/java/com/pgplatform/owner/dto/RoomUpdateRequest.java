package com.pgplatform.owner.dto;

import com.pgplatform.owner.RoomType;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public record RoomUpdateRequest(
        @NotBlank String roomNumber,
        @NotNull @Min(1) Integer sharingCount,
        @NotNull @DecimalMin("0.0") BigDecimal rentPerBed,
        @NotNull RoomType roomType
) {
}
