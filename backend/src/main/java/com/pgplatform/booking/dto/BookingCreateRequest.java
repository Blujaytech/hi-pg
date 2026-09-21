package com.pgplatform.booking.dto;

import com.pgplatform.booking.BookingType;
import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.UUID;

public record BookingCreateRequest(
        @NotNull UUID bedId,
        @NotNull BookingType bookingType,
        @NotNull @FutureOrPresent LocalDate checkInDate,
        LocalDate checkOutDate
) {
    /** Compatibility for older callers; creates an open-ended monthly request. */
    public BookingCreateRequest(UUID bedId, LocalDate moveInDate) {
        this(bedId, BookingType.MONTHLY, moveInDate, null);
    }
}
