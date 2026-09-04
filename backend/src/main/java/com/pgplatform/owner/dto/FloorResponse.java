package com.pgplatform.owner.dto;

import com.pgplatform.owner.Floor;

import java.util.UUID;

public record FloorResponse(UUID id, UUID pgId, String name, Integer floorNumber) {
    public static FloorResponse from(Floor floor) {
        return new FloorResponse(floor.getId(), floor.getPg().getId(), floor.getName(), floor.getFloorNumber());
    }
}
