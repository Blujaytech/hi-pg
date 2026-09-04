package com.pgplatform.payment;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** Blank by default (no Razorpay account provisioned yet) -- see StubRazorpayGateway and docs/decisions.md. */
@ConfigurationProperties(prefix = "app.razorpay")
public class RazorpayProperties {
    private String keyId = "";
    private String keySecret = "";
    private String webhookSecret = "";

    public String getKeyId() {
        return keyId;
    }

    public void setKeyId(String keyId) {
        this.keyId = keyId;
    }

    public String getKeySecret() {
        return keySecret;
    }

    public void setKeySecret(String keySecret) {
        this.keySecret = keySecret;
    }

    public String getWebhookSecret() {
        return webhookSecret;
    }

    public void setWebhookSecret(String webhookSecret) {
        this.webhookSecret = webhookSecret;
    }

    public boolean isConfigured() {
        return !keyId.isBlank() && !keySecret.isBlank();
    }
}
