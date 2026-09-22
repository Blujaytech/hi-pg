package com.pgplatform.payment.dto;

import com.pgplatform.booking.Booking;
import com.pgplatform.booking.BookingType;
import com.pgplatform.payment.DirectPaymentRequest;
import com.pgplatform.payment.DirectPaymentStatus;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

public record DirectPaymentRequestResponse(
        UUID id,
        UUID bookingId,
        UUID pgId,
        String pgName,
        String customerName,
        String maskedCustomerPhone,
        UUID bedId,
        String bedLabel,
        String roomNumber,
        BookingType bookingType,
        LocalDate checkInDate,
        LocalDate checkOutDate,
        BigDecimal quotedAmount,
        String currency,
        String transactionReference,
        DirectPaymentStatus status,
        Instant submittedAt,
        Instant reviewDueAt,
        BigDecimal confirmedAmount,
        Instant reviewedAt,
        String rejectionReason
) {
    public static DirectPaymentRequestResponse from(DirectPaymentRequest request) {
        Booking booking = request.getBooking();
        return new DirectPaymentRequestResponse(request.getId(), booking.getId(), request.getPg().getId(),
                request.getPg().getName(), request.getCustomer().getFullName(), mask(request.getCustomer().getPhone()),
                booking.getBed().getId(), booking.getBed().getLabel(), booking.getBed().getRoom().getRoomNumber(),
                booking.getBookingType(), booking.getMoveInDate(), booking.getCheckOutDate(),
                request.getQuotedAmount(), request.getCurrency(), request.getTransactionReference(),
                request.getStatus(), request.getSubmittedAt(), request.getReviewDueAt(),
                request.getConfirmedAmount(), request.getReviewedAt(), request.getRejectionReason());
    }

    private static String mask(String value) {
        if (value == null || value.length() < 4) return "XXXX";
        return value.substring(0, 2) + "X".repeat(Math.max(4, value.length() - 4))
                + value.substring(value.length() - 2);
    }
}
