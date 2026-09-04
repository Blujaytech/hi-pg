package com.pgplatform.notification;

/**
 * Abstraction over "send this message to a human". Phase 13 adds
 * {@code sendPush} (push is first per the technical plan: "cheapest,
 * fastest feedback loop") alongside the SMS/email methods already here
 * since Phase 1/6-ish groundwork. LoggingNotificationGateway is the only
 * implementation until real FCM/email-provider credentials are configured
 * -- see docs/decisions.md ADR-0020. WhatsApp (Business API) is explicitly
 * out of scope for this phase per the technical plan (Meta approval lead
 * time) -- not represented here at all yet.
 */
public interface NotificationGateway {
    void sendSms(String toPhone, String message);
    void sendEmail(String toEmail, String subject, String body);
    void sendPush(String deviceToken, String title, String body);
}
