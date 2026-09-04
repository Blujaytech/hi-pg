package com.pgplatform.complaint.dto;

import com.pgplatform.complaint.ComplaintStatus;
import jakarta.validation.constraints.NotNull;

public record ComplaintStatusUpdateRequest(
        @NotNull ComplaintStatus status,
        String resolutionNotes
) {
}
