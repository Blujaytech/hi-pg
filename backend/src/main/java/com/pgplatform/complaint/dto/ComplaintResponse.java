package com.pgplatform.complaint.dto;

import com.pgplatform.complaint.Complaint;
import com.pgplatform.complaint.ComplaintCategory;
import com.pgplatform.complaint.ComplaintPriority;
import com.pgplatform.complaint.ComplaintStatus;

import java.time.Instant;
import java.util.UUID;

public record ComplaintResponse(
        UUID id,
        UUID studentId,
        String studentName,
        UUID pgId,
        String pgName,
        String roomNumber,
        String bedLabel,
        ComplaintCategory category,
        ComplaintPriority priority,
        String description,
        ComplaintStatus status,
        String resolutionNotes,
        Instant resolvedAt,
        Instant createdAt
) {
    public static ComplaintResponse from(Complaint complaint) {
        return new ComplaintResponse(
                complaint.getId(),
                complaint.getStudent().getId(),
                complaint.getStudent().getFullName(),
                complaint.getPg().getId(),
                complaint.getPg().getName(),
                complaint.getStudent().getBed() == null ? null
                        : complaint.getStudent().getBed().getRoom().getRoomNumber(),
                complaint.getStudent().getBed() == null ? null
                        : complaint.getStudent().getBed().getLabel(),
                complaint.getCategory(),
                complaint.getPriority(),
                complaint.getDescription(),
                complaint.getStatus(),
                complaint.getResolutionNotes(),
                complaint.getResolvedAt(),
                complaint.getCreatedAt()
        );
    }
}
