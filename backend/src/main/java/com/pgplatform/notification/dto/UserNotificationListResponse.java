package com.pgplatform.notification.dto;

import java.util.List;

public record UserNotificationListResponse(
        List<UserNotificationResponse> notifications,
        long unreadCount
) { }
