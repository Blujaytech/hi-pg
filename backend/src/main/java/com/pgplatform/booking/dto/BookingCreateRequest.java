package com.pgplatform.booking.dto;

import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.UUID;

public record BookingCreateRequest(
        @NotNull UUID bedId,
        @NotNull @FutureOrPresent LocalDate moveInDate
) {
}
