package com.pgplatform.auth.dto;

import com.pgplatform.auth.Role;

import java.util.UUID;

public record AuthResponse(
        String accessToken,
        String refreshToken,
        UUID userId,
        String fullName,
        Role role
) {
}
