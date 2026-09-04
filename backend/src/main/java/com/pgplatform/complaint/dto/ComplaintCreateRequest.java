package com.pgplatform.complaint.dto;

import com.pgplatform.complaint.ComplaintCategory;
import com.pgplatform.complaint.ComplaintPriority;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record ComplaintCreateRequest(
        @NotNull ComplaintCategory category,
        ComplaintPriority priority,
        @NotBlank String description
) {
}
