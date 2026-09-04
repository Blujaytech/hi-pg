package com.pgplatform.booking.dto;

import com.pgplatform.booking.Booking;
import com.pgplatform.booking.BookingStatus;

import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

public record BookingResponse(
        UUID id,
        UUID studentId,
        UUID pgId,
        String pgName,
        UUID bedId,
        String bedLabel,
        String roomNumber,
        BookingStatus status,
        LocalDate moveInDate,
        Instant confirmedAt,
        Instant cancelledAt,
        String cancellationReason
) {
    public static BookingResponse from(Booking booking) {
        return new BookingResponse(
                booking.getId(), booking.getStudent().getId(), booking.getPg().getId(), booking.getPg().getName(),
                booking.getBed().getId(), booking.getBed().getLabel(), booking.getBed().getRoom().getRoomNumber(),
                booking.getStatus(), booking.getMoveInDate(), booking.getConfirmedAt(), booking.getCancelledAt(),
                booking.getCancellationReason()
        );
    }
}
