package com.pgplatform.notification;

import java.time.Instant;
import java.util.UUID;

/** Phase 14 -- a live, in-app echo of a notification (see UserEventBroadcaster). */
public record UserEvent(
        UUID notificationId,
        String title,
        String message,
        NotificationCategory category,
        String actionRoute,
        Instant sentAt
) {
}
