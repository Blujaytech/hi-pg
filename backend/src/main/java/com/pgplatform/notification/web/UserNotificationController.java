package com.pgplatform.notification.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.notification.NotificationService;
import com.pgplatform.notification.dto.UserNotificationListResponse;
import com.pgplatform.notification.dto.UserNotificationResponse;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
public class UserNotificationController {

    private final NotificationService notificationService;

    public UserNotificationController(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @GetMapping("/api/v1/me/notifications")
    public UserNotificationListResponse list(@AuthenticationPrincipal UserPrincipal principal,
                                             @RequestParam(defaultValue = "50") int limit) {
        return notificationService.list(principal.getId(), limit);
    }

    @PatchMapping("/api/v1/me/notifications/{notificationId}/read")
    public UserNotificationResponse markRead(@AuthenticationPrincipal UserPrincipal principal,
                                             @PathVariable UUID notificationId) {
        return notificationService.markRead(principal.getId(), notificationId);
    }

    @PatchMapping("/api/v1/me/notifications/read-all")
    public ResponseEntity<Void> markAllRead(@AuthenticationPrincipal UserPrincipal principal) {
        notificationService.markAllRead(principal.getId());
        return ResponseEntity.noContent().build();
    }
}
