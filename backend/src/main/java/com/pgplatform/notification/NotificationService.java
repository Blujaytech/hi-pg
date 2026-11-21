package com.pgplatform.notification;

import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.UserStatus;
import com.pgplatform.auth.PhoneNumbers;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.notification.dto.AdminMessageAudience;
import com.pgplatform.notification.dto.AdminMessageRequest;
import com.pgplatform.notification.dto.AdminMessageResponse;
import com.pgplatform.notification.dto.UserNotificationListResponse;
import com.pgplatform.notification.dto.UserNotificationResponse;
import org.springframework.data.domain.PageRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

/**
 * The one place the rest of the app should call to notify a user -- fans
 * out to every registered device token (push) and to email if the user has
 * one, via NotificationGateway. Callers never touch NotificationGateway
 * directly (see BookingService, PaymentOrderService, ComplaintService for
 * the Phase 13 wiring). Deliberately swallows gateway failures per
 * recipient -- a notification failing must never fail the business
 * operation that triggered it (a confirmed booking is still confirmed even
 * if sending the "you're booked!" push fails).
 */
@Service
public class NotificationService {

    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);

    private final NotificationGateway gateway;
    private final DeviceTokenRepository deviceTokenRepository;
    private final UserRepository userRepository;
    private final UserNotificationRepository notificationRepository;
    private final UserEventBroadcaster userEventBroadcaster;

    public NotificationService(NotificationGateway gateway, DeviceTokenRepository deviceTokenRepository,
                                UserRepository userRepository, UserNotificationRepository notificationRepository,
                                UserEventBroadcaster userEventBroadcaster) {
        this.gateway = gateway;
        this.deviceTokenRepository = deviceTokenRepository;
        this.userRepository = userRepository;
        this.notificationRepository = notificationRepository;
        this.userEventBroadcaster = userEventBroadcaster;
    }

    @Transactional
    public void notifyUser(UUID userId, String title, String message) {
        notifyUser(userId, title, message, inferCategory(title), null);
    }

    @Transactional
    public void notifyUser(UUID userId, String title, String message,
                           NotificationCategory category, String actionRoute) {
        if (userId == null) {
            return;
        }
        User user = userRepository.findByIdAndDeletedAtIsNull(userId).orElse(null);
        if (user == null) {
            return;
        }

        UserNotification notification = new UserNotification();
        notification.setUser(user);
        notification.setTitle(requireText(title, "Notification title", 120));
        notification.setMessage(requireText(message, "Notification message", 2000));
        notification.setCategory(category == null ? NotificationCategory.GENERAL : category);
        notification.setActionRoute(normalizeRoute(actionRoute));
        notification = notificationRepository.save(notification);

        if (user.getEmail() != null && !user.getEmail().isBlank()) {
            UserNotification saved = notification;
            safely(() -> gateway.sendEmail(user.getEmail(), saved.getTitle(), saved.getMessage()));
        }

        List<DeviceToken> tokens = deviceTokenRepository.findAllByUserIdAndDeletedAtIsNull(userId);
        Map<String, String> data = pushData(notification);
        for (DeviceToken token : tokens) {
            UserNotification saved = notification;
            safely(() -> gateway.sendPush(
                    token.getToken(), saved.getTitle(), saved.getMessage(), data));
        }

        UserNotification saved = notification;
        safely(() -> userEventBroadcaster.publish(userId, saved));
    }

    @Transactional(readOnly = true)
    public UserNotificationListResponse list(UUID userId, int requestedLimit) {
        int limit = Math.max(1, Math.min(requestedLimit, 100));
        List<UserNotificationResponse> notifications = notificationRepository
                .findAllByUserIdAndDeletedAtIsNullOrderByCreatedAtDesc(userId, PageRequest.of(0, limit))
                .stream()
                .map(NotificationService::response)
                .toList();
        long unreadCount = notificationRepository.countByUserIdAndReadAtIsNullAndDeletedAtIsNull(userId);
        return new UserNotificationListResponse(notifications, unreadCount);
    }

    @Transactional
    public UserNotificationResponse markRead(UUID userId, UUID notificationId) {
        UserNotification notification = notificationRepository
                .findByIdAndUserIdAndDeletedAtIsNull(notificationId, userId)
                .orElseThrow(() -> new NotFoundException("Notification not found"));
        if (notification.getReadAt() == null) {
            notification.setReadAt(Instant.now());
            notification = notificationRepository.save(notification);
        }
        return response(notification);
    }

    @Transactional
    public void markAllRead(UUID userId) {
        List<UserNotification> unread = notificationRepository
                .findAllByUserIdAndReadAtIsNullAndDeletedAtIsNull(userId);
        Instant now = Instant.now();
        unread.forEach(notification -> notification.setReadAt(now));
        notificationRepository.saveAll(unread);
    }

    @Transactional
    public AdminMessageResponse sendAdminMessage(AdminMessageRequest request) {
        List<String> unresolved = new ArrayList<>();
        List<User> users = resolveRecipients(request, unresolved);
        NotificationCategory category = request.category() == null
                ? NotificationCategory.GENERAL : request.category();
        int pushDevices = 0;
        for (User user : users) {
            pushDevices += deviceTokenRepository.findAllByUserIdAndDeletedAtIsNull(user.getId()).size();
            notifyUser(user.getId(), request.title(), request.message(), category, request.actionRoute());
        }
        return new AdminMessageResponse(users.size(), pushDevices, unresolved);
    }

    private List<User> resolveRecipients(AdminMessageRequest request, List<String> unresolved) {
        return switch (request.audience()) {
            case ALL -> userRepository.findAllByStatusAndDeletedAtIsNull(UserStatus.ACTIVE);
            case OWNERS -> userRepository.findAllByRoleAndStatusAndDeletedAtIsNull(Role.OWNER, UserStatus.ACTIVE);
            case STUDENTS -> userRepository.findAllByRoleAndStatusAndDeletedAtIsNull(Role.STUDENT, UserStatus.ACTIVE);
            case DIRECT -> resolveDirect(request.recipients(), unresolved);
        };
    }

    private List<User> resolveDirect(List<String> recipients, List<String> unresolved) {
        if (recipients == null || recipients.isEmpty()) {
            throw new IllegalArgumentException("At least one recipient email, phone or user ID is required");
        }
        Map<UUID, User> users = new LinkedHashMap<>();
        for (String raw : recipients) {
            String identifier = raw == null ? "" : raw.trim();
            User user = findUser(identifier);
            if (user == null || user.getStatus() != UserStatus.ACTIVE) {
                unresolved.add(identifier);
            } else {
                users.put(user.getId(), user);
            }
        }
        if (users.isEmpty()) {
            throw new IllegalArgumentException("No active users matched the supplied recipients");
        }
        return List.copyOf(users.values());
    }

    private User findUser(String identifier) {
        if (identifier.isBlank()) return null;
        try {
            return userRepository.findByIdAndDeletedAtIsNull(UUID.fromString(identifier)).orElse(null);
        } catch (IllegalArgumentException ignored) {
            // Not a UUID; continue with human identifiers.
        }
        if (identifier.contains("@")) {
            return userRepository.findByEmailIgnoreCaseAndDeletedAtIsNull(identifier).orElse(null);
        }
        try {
            return userRepository.findByPhoneAndDeletedAtIsNull(PhoneNumbers.normalize(identifier)).orElse(null);
        } catch (IllegalArgumentException ignored) {
            return null;
        }
    }

    private static UserNotificationResponse response(UserNotification notification) {
        return new UserNotificationResponse(
                notification.getId(), notification.getTitle(), notification.getMessage(),
                notification.getCategory(), notification.getActionRoute(),
                notification.getReadAt() != null, notification.getCreatedAt());
    }

    private static Map<String, String> pushData(UserNotification notification) {
        Map<String, String> data = new LinkedHashMap<>();
        data.put("type", "USER_EVENT");
        data.put("notificationId", notification.getId().toString());
        data.put("category", notification.getCategory().name());
        data.put("actionRoute", notification.getActionRoute() == null
                ? "/notifications" : notification.getActionRoute());
        return Map.copyOf(data);
    }

    private static String requireText(String value, String label, int max) {
        if (value == null || value.isBlank()) throw new IllegalArgumentException(label + " is required");
        String normalized = value.trim();
        if (normalized.length() > max) throw new IllegalArgumentException(label + " is too long");
        return normalized;
    }

    private static String normalizeRoute(String route) {
        if (route == null || route.isBlank()) return null;
        String normalized = route.trim();
        if (!normalized.startsWith("/") || normalized.startsWith("//")
                || normalized.toLowerCase(Locale.ROOT).startsWith("/http")) {
            throw new IllegalArgumentException("Notification action route must be an internal app path");
        }
        return normalized;
    }

    private static NotificationCategory inferCategory(String title) {
        String value = title == null ? "" : title.toLowerCase(Locale.ROOT);
        if (value.contains("booking") || value.contains("check-in") || value.contains("move-out")) {
            return NotificationCategory.BOOKING;
        }
        if (value.contains("payment") || value.contains("rent") || value.contains("fee")
                || value.contains("deposit") || value.contains("autopay") || value.contains("settlement")) {
            return NotificationCategory.PAYMENT;
        }
        if (value.contains("complaint")) return NotificationCategory.COMPLAINT;
        if (value.contains("support")) return NotificationCategory.SUPPORT;
        if (value.contains("kyc") || value.contains("account")) return NotificationCategory.ACCOUNT;
        if (value.contains("pg") || value.contains("property") || value.contains("claim")) {
            return NotificationCategory.PROPERTY;
        }
        return NotificationCategory.GENERAL;
    }

    private void safely(Runnable action) {
        try {
            action.run();
        } catch (Exception e) {
            log.warn("Notification delivery failed (non-fatal): {}", e.getMessage());
        }
    }
}
