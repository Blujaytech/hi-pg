package com.pgplatform.booking.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.pgplatform.booking.BookingType;
import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;

public record BookingCreateRequest(
        @NotNull UUID bedId,
        @NotNull BookingType bookingType,
        @JsonAlias("moveInDate") @NotNull @FutureOrPresent LocalDate checkInDate,
        LocalDate checkOutDate,
        LocalTime checkOutTime
) {
    /**
     * Keep already-installed clients working across the flexible-booking API
     * rollout. Those clients only sent bedId + moveInDate, which otherwise
     * deserializes with a null bookingType/checkInDate and is rejected by bean
     * validation before BookingService can run.
     */
    public BookingCreateRequest {
        if (bookingType == null) {
            bookingType = BookingType.MONTHLY;
        }
        if (bookingType == BookingType.DAY_WISE && checkOutTime == null) {
            checkOutTime = LocalTime.of(11, 0);
        }
    }

    /** Compatibility for older callers; creates an open-ended monthly request. */
    public BookingCreateRequest(UUID bedId, LocalDate moveInDate) {
        this(bedId, BookingType.MONTHLY, moveInDate, null, null);
    }

    /** Compatibility for tests and clients introduced before checkout time. */
    public BookingCreateRequest(UUID bedId, BookingType bookingType,
                                LocalDate checkInDate, LocalDate checkOutDate) {
        this(bedId, bookingType, checkInDate, checkOutDate, null);
    }
}
