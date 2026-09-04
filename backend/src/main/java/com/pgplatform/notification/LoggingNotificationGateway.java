package com.pgplatform.notification;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * Dev/placeholder implementation: logs instead of actually sending. Replace
 * with real FCM (push) / SES-Postmark-Resend (email) / SMS provider
 * integrations without touching any caller of NotificationGateway -- see
 * docs/decisions.md ADR-0020.
 */
@Component
public class LoggingNotificationGateway implements NotificationGateway {

    private static final Logger log = LoggerFactory.getLogger(LoggingNotificationGateway.class);

    @Override
    public void sendSms(String toPhone, String message) {
        log.info("[SMS -> {}] {}", toPhone, message);
    }

    @Override
    public void sendEmail(String toEmail, String subject, String body) {
        log.info("[EMAIL -> {}] subject='{}' body='{}'", toEmail, subject, body);
    }

    @Override
    public void sendPush(String deviceToken, String title, String body) {
        log.info("[PUSH -> {}] title='{}' body='{}'", deviceToken, title, body);
    }
}
