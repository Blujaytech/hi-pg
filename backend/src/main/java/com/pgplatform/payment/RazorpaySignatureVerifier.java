package com.pgplatform.payment;

import org.springframework.stereotype.Component;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

/**
 * Razorpay signs each webhook body with HMAC-SHA256 using the webhook
 * secret configured in the Razorpay dashboard (`X-Razorpay-Signature`
 * header = hex-encoded HMAC of the raw request body). This class is fully
 * implemented and unit-tested today, independent of whether a real
 * Razorpay account exists -- see RazorpayWebhookServiceTest, which computes
 * a signature the same way Razorpay itself would.
 */
@Component
public class RazorpaySignatureVerifier {

    private static final String HMAC_ALGORITHM = "HmacSHA256";

    public boolean isValid(String rawBody, String signatureHeader, String webhookSecret) {
        if (webhookSecret == null || webhookSecret.isBlank() || signatureHeader == null || signatureHeader.isBlank()) {
            return false;
        }
        String expected = computeSignature(rawBody, webhookSecret);
        return constantTimeEquals(expected, signatureHeader.trim());
    }

    public String computeSignature(String rawBody, String webhookSecret) {
        try {
            Mac mac = Mac.getInstance(HMAC_ALGORITHM);
            mac.init(new SecretKeySpec(webhookSecret.getBytes(StandardCharsets.UTF_8), HMAC_ALGORITHM));
            byte[] hash = mac.doFinal(rawBody.getBytes(StandardCharsets.UTF_8));
            StringBuilder hex = new StringBuilder(hash.length * 2);
            for (byte b : hash) {
                hex.append(String.format("%02x", b));
            }
            return hex.toString();
        } catch (Exception e) {
            throw new IllegalStateException("Failed to compute Razorpay webhook signature", e);
        }
    }

    private boolean constantTimeEquals(String a, String b) {
        return MessageDigest.isEqual(a.getBytes(StandardCharsets.UTF_8), b.getBytes(StandardCharsets.UTF_8));
    }
}
