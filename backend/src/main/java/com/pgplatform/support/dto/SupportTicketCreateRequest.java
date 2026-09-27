package com.pgplatform.support.dto;

import com.pgplatform.support.SupportCategory;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record SupportTicketCreateRequest(
        @NotNull SupportCategory category,
        @NotBlank @Size(min = 5, max = 120) String subject,
        @NotBlank @Size(min = 10, max = 2000) String description
) {
}
