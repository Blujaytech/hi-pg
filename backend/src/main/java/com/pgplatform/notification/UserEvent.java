package com.pgplatform.notification;

import java.time.Instant;

/** Phase 14 -- a live, in-app echo of a notification (see UserEventBroadcaster). */
public record UserEvent(String title, String message, Instant sentAt) {
}
