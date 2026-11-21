package com.pgplatform.notification;

import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.util.Map;

/** Production push delivery through FCM HTTP v1 using Cloud Run ADC. */
@Component
@ConditionalOnProperty(name = "app.firebase.enabled", havingValue = "true")
public class FirebaseNotificationGateway implements NotificationGateway {

    private static final Logger log = LoggerFactory.getLogger(FirebaseNotificationGateway.class);
    private final FirebaseMessaging messaging;

    public FirebaseNotificationGateway(FirebaseMessaging messaging) {
        this.messaging = messaging;
    }

    @Override
    public void sendSms(String toPhone, String message) {
        // Login OTP is sent by Firebase Auth directly from the mobile SDK.
        log.info("No transactional SMS provider configured for {}", toPhone);
    }

    @Override
    public void sendEmail(String toEmail, String subject, String body) {
        log.info("No transactional email provider configured for {} (subject={})", toEmail, subject);
    }

    @Override
    public void sendPush(String deviceToken, String title, String body, Map<String, String> data) {
        boolean discovery = NotificationCategory.DISCOVERY.name().equals(data.get("category"));
        Message message = Message.builder()
                .setToken(deviceToken)
                .setNotification(Notification.builder().setTitle(title).setBody(body).build())
                .setAndroidConfig(AndroidConfig.builder()
                        .setPriority(discovery ? AndroidConfig.Priority.NORMAL : AndroidConfig.Priority.HIGH)
                        .setNotification(AndroidNotification.builder()
                                .setChannelId(discovery ? "hipg_discovery" : "hipg_updates")
                                .setIcon("ic_stat_hipg")
                                .setColor("#F84464")
                                .build())
                        .build())
                .putAllData(data)
                .build();
        try {
            messaging.send(message);
        } catch (FirebaseMessagingException exception) {
            throw new IllegalStateException("FCM delivery failed: " + exception.getMessagingErrorCode(), exception);
        }
    }
}
