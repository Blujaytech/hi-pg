package com.pgplatform.owner.dto;

import com.pgplatform.owner.RoomType;
import com.pgplatform.owner.RoomBookingMode;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public record RoomCreateRequest(
        @NotBlank String roomNumber,
        @NotNull @Min(1) Integer sharingCount,
        @NotNull @DecimalMin("0.0") BigDecimal rentPerBed,
        @NotNull RoomType roomType,
        @NotNull RoomBookingMode bookingMode,
        @DecimalMin("0.0") BigDecimal dayWiseRate,
        @NotNull @Min(0) Integer noticePeriodDays,
        @NotNull @DecimalMin("0.0") BigDecimal securityDeposit
) {
    public RoomCreateRequest(String roomNumber, Integer sharingCount, BigDecimal rentPerBed, RoomType roomType) {
        this(roomNumber, sharingCount, rentPerBed, roomType, RoomBookingMode.MONTHLY,
                null, 15, BigDecimal.ZERO);
    }
}
