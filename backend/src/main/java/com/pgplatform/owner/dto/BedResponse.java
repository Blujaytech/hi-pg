package com.pgplatform.owner.dto;

import com.pgplatform.owner.Bed;
import com.pgplatform.owner.BedStatus;
import com.pgplatform.owner.BedBookingMode;
import com.pgplatform.student.Student;

import java.time.LocalDate;
import java.util.UUID;

public record BedResponse(UUID id, UUID roomId, String label, BedStatus status,
                          BedBookingMode bookingMode, BedOccupantResponse occupant) {
    public static BedResponse from(Bed bed) {
        return new BedResponse(bed.getId(), bed.getRoom().getId(), bed.getLabel(), bed.getStatus(),
                bed.getBookingMode(), null);
    }

    public static BedResponse from(Bed bed, Student occupant) {
        BedOccupantResponse occupantResponse = occupant == null ? null : new BedOccupantResponse(
                occupant.getId(), occupant.getFullName(), occupant.getPhone(), occupant.getGuardianName(),
                occupant.getGuardianPhone(), occupant.getDateOfJoining()
        );
        return new BedResponse(bed.getId(), bed.getRoom().getId(), bed.getLabel(), bed.getStatus(),
                bed.getBookingMode(), occupantResponse);
    }

    /** Owner-only (this DTO is never used by the public discovery endpoints) -- includes contact details deliberately. */
    public record BedOccupantResponse(UUID studentId, String fullName, String phone, String guardianName,
                                       String guardianPhone, LocalDate dateOfJoining) {
    }
}
