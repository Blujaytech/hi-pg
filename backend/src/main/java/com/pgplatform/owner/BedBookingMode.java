package com.pgplatform.owner;

import com.pgplatform.booking.BookingType;

public enum BedBookingMode {
    MONTHLY,
    DAY_WISE,
    FLEXIBLE;

    public boolean supports(BookingType type) {
        return this == FLEXIBLE || name().equals(type.name());
    }
}
