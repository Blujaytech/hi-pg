package com.pgplatform.discovery.dto;

import com.pgplatform.owner.RoomType;
import com.pgplatform.owner.RoomBookingMode;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record RoomAvailabilityResponse(
        UUID roomId,
        String roomNumber,
        RoomType roomType,
        int sharingCount,
        BigDecimal rentPerBed,
        BigDecimal dayWiseRate,
        RoomBookingMode bookingMode,
        int noticePeriodDays,
        BigDecimal securityDeposit,
        long availableBeds,
        List<AvailableBedSummary> availableBedOptions,
        // Every bed in the room, free or not, so clients can draw the whole
        // room and grey out the taken beds.
        List<BedSeatSummary> beds
) {
}
