package com.pgplatform.notification.dto;

import com.pgplatform.notification.NotificationCategory;

import java.time.Instant;
import java.util.UUID;

public record UserNotificationResponse(
        UUID id,
        String title,
        String message,
        NotificationCategory category,
        String actionRoute,
        boolean read,
        Instant createdAt
) { }
