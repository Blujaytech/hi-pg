package com.pgplatform.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record AccountDeletionRequest(
        @NotBlank String confirmation,
        String currentPassword
) {
}
