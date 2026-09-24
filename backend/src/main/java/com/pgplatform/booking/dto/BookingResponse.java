package com.pgplatform.booking.dto;

import com.pgplatform.booking.Booking;
import com.pgplatform.booking.BookingStatus;
import com.pgplatform.booking.BookingType;
import com.pgplatform.booking.BookingPaymentChannel;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;
import java.math.BigDecimal;

public record BookingResponse(
        UUID id,
        UUID studentId,
        UUID pgId,
        String pgName,
        UUID bedId,
        String bedLabel,
        String roomNumber,
        BookingStatus status,
        BookingType bookingType,
        BookingPaymentChannel paymentChannel,
        LocalDate checkInDate,
        LocalDate checkOutDate,
        LocalTime checkOutTime,
        BigDecimal rentAmount,
        BigDecimal securityDepositAmount,
        BigDecimal totalAmount,
        Instant paymentExpiresAt,
        Instant confirmedAt,
        Instant cancelledAt,
        String cancellationReason,
        LocalDate plannedMoveOutDate,
        Integer noticeShortfallDays
) {
    public static BookingResponse from(Booking booking) {
        return new BookingResponse(
                booking.getId(), booking.getStudent().getId(), booking.getPg().getId(), booking.getPg().getName(),
                booking.getBed().getId(), booking.getBed().getLabel(), booking.getBed().getRoom().getRoomNumber(),
                booking.getStatus(), booking.getBookingType(), booking.getPaymentChannel(),
                booking.getMoveInDate(), booking.getCheckOutDate(),
                booking.getCheckOutTime(),
                booking.getRentAmount(), booking.getSecurityDepositAmount(), booking.getTotalAmount(),
                booking.getPaymentExpiresAt(), booking.getConfirmedAt(), booking.getCancelledAt(),
                booking.getCancellationReason(), booking.getPlannedMoveOutDate(), booking.getNoticeShortfallDays()
        );
    }
}
