package com.pgplatform.booking.dto;

import jakarta.validation.constraints.FutureOrPresent;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

public record MoveOutNoticeRequest(@NotNull @FutureOrPresent LocalDate plannedMoveOutDate) {
}
