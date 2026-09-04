package com.pgplatform.owner.dto;

import com.pgplatform.owner.Bed;
import com.pgplatform.owner.BedStatus;

import java.util.UUID;

public record BedResponse(UUID id, UUID roomId, String label, BedStatus status) {
    public static BedResponse from(Bed bed) {
        return new BedResponse(bed.getId(), bed.getRoom().getId(), bed.getLabel(), bed.getStatus());
    }
}
