package com.pgplatform.support.dto;

import com.pgplatform.support.SupportStatus;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record SupportTicketAdminUpdateRequest(
        @NotNull SupportStatus status,
        @NotBlank @Size(min = 3, max = 2000) String response
) {
}
