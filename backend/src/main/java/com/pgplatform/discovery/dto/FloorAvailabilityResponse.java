package com.pgplatform.discovery.dto;

import java.util.List;
import java.util.UUID;

public record FloorAvailabilityResponse(
        UUID floorId,
        String name,
        int floorNumber,
        List<RoomAvailabilityResponse> rooms
) {
}
