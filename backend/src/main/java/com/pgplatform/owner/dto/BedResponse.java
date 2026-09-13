package com.pgplatform.owner.dto;

import com.pgplatform.owner.Bed;
import com.pgplatform.owner.BedStatus;
import com.pgplatform.student.Student;

import java.time.LocalDate;
import java.util.UUID;

public record BedResponse(UUID id, UUID roomId, String label, BedStatus status, BedOccupantResponse occupant) {
    public static BedResponse from(Bed bed) {
        return new BedResponse(bed.getId(), bed.getRoom().getId(), bed.getLabel(), bed.getStatus(), null);
    }

    public static BedResponse from(Bed bed, Student occupant) {
        BedOccupantResponse occupantResponse = occupant == null ? null : new BedOccupantResponse(
                occupant.getId(), occupant.getFullName(), occupant.getPhone(), occupant.getGuardianName(),
                occupant.getGuardianPhone(), occupant.getDateOfJoining()
        );
        return new BedResponse(bed.getId(), bed.getRoom().getId(), bed.getLabel(), bed.getStatus(), occupantResponse);
    }

    /** Owner-only (this DTO is never used by the public discovery endpoints) -- includes contact details deliberately. */
    public record BedOccupantResponse(UUID studentId, String fullName, String phone, String guardianName,
                                       String guardianPhone, LocalDate dateOfJoining) {
    }
}
