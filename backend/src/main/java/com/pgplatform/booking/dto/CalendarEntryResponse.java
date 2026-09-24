package com.pgplatform.booking.dto;

import com.pgplatform.booking.Booking;
import com.pgplatform.booking.BookingStatus;
import com.pgplatform.booking.BookingType;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;

public record CalendarEntryResponse(
        UUID bookingId,
        UUID bedId,
        String bedLabel,
        String customerName,
        BookingType bookingType,
        BookingStatus status,
        LocalDate startDate,
        LocalDate endDate,
        LocalTime checkOutTime,
        Instant paymentExpiresAt
) {
    public static CalendarEntryResponse from(Booking booking) {
        return new CalendarEntryResponse(
                booking.getId(), booking.getBed().getId(), booking.getBed().getLabel(),
                booking.getStudent().getFullName(), booking.getBookingType(), booking.getStatus(),
                booking.getMoveInDate(), booking.getCheckOutDate(), booking.getCheckOutTime(),
                booking.getPaymentExpiresAt()
        );
    }
}
