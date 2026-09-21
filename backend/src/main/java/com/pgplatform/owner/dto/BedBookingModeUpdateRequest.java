package com.pgplatform.owner.dto;

import com.pgplatform.owner.BedBookingMode;
import jakarta.validation.constraints.NotNull;

public record BedBookingModeUpdateRequest(@NotNull BedBookingMode bookingMode) {
}
