package com.pgplatform.notification;

import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
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
    private final UserEventBroadcaster userEventBroadcaster;

    public NotificationService(NotificationGateway gateway, DeviceTokenRepository deviceTokenRepository,
                                UserRepository userRepository, UserEventBroadcaster userEventBroadcaster) {
        this.gateway = gateway;
        this.deviceTokenRepository = deviceTokenRepository;
        this.userRepository = userRepository;
        this.userEventBroadcaster = userEventBroadcaster;
    }

    @Transactional(readOnly = true)
    public void notifyUser(UUID userId, String title, String message) {
        if (userId == null) {
            return;
        }
        User user = userRepository.findByIdAndDeletedAtIsNull(userId).orElse(null);
        if (user == null) {
            return;
        }

        if (user.getEmail() != null && !user.getEmail().isBlank()) {
            safely(() -> gateway.sendEmail(user.getEmail(), title, message));
        }

        List<DeviceToken> tokens = deviceTokenRepository.findAllByUserIdAndDeletedAtIsNull(userId);
        for (DeviceToken token : tokens) {
            safely(() -> gateway.sendPush(token.getToken(), title, message));
        }

        // Phase 14: live in-app echo for anyone with the app open right now, on top of push/email above.
        safely(() -> userEventBroadcaster.publish(userId, title, message));
    }

    private void safely(Runnable action) {
        try {
            action.run();
        } catch (Exception e) {
            log.warn("Notification delivery failed (non-fatal): {}", e.getMessage());
        }
    }
}
