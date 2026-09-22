package com.pgplatform.student.dto;

import com.pgplatform.booking.BookingType;

import java.util.List;

public record BookingEligibilityResponse(
        BookingType bookingType,
        boolean eligible,
        List<String> missingRequirements
) {
}
