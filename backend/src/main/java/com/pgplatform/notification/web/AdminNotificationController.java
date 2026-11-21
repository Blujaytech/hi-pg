package com.pgplatform.notification.web;

import com.pgplatform.notification.NotificationService;
import com.pgplatform.notification.dto.AdminMessageRequest;
import com.pgplatform.notification.dto.AdminMessageResponse;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin/notifications")
@PreAuthorize("hasRole('ADMIN')")
public class AdminNotificationController {

    private final NotificationService notificationService;

    public AdminNotificationController(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @PostMapping
    public AdminMessageResponse send(@Valid @RequestBody AdminMessageRequest request) {
        return notificationService.sendAdminMessage(request);
    }
}
