package com.pgplatform.discovery.dto;

import com.pgplatform.owner.RoomType;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record RoomAvailabilityResponse(
        UUID roomId,
        String roomNumber,
        RoomType roomType,
        int sharingCount,
        BigDecimal rentPerBed,
        long availableBeds,
        List<AvailableBedSummary> availableBedOptions
) {
}
