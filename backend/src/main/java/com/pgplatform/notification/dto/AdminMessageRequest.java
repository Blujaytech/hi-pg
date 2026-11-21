package com.pgplatform.notification.dto;

import com.pgplatform.notification.NotificationCategory;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

public record AdminMessageRequest(
        @NotNull AdminMessageAudience audience,
        List<@NotBlank @Size(max = 320) String> recipients,
        @NotBlank @Size(max = 120) String title,
        @NotBlank @Size(max = 2000) String message,
        NotificationCategory category,
        @Size(max = 255) String actionRoute
) { }
