package com.pgplatform.payment.web;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.pgplatform.payment.PaymentOrderService;
import com.pgplatform.payment.RazorpayProperties;
import com.pgplatform.payment.RazorpaySignatureVerifier;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;

/**
 * Unauthenticated by design (Razorpay calls this, not a logged-in user) --
 * see SecurityConfig's `/api/v1/webhooks/**` permitAll. Authenticity comes
 * entirely from the HMAC signature check, not from a session/JWT.
 */
@RestController
public class RazorpayWebhookController {

    private static final Logger log = LoggerFactory.getLogger(RazorpayWebhookController.class);

    private final PaymentOrderService paymentOrderService;
    private final RazorpaySignatureVerifier signatureVerifier;
    private final RazorpayProperties razorpayProperties;
    private final ObjectMapper objectMapper;

    public RazorpayWebhookController(PaymentOrderService paymentOrderService, RazorpaySignatureVerifier signatureVerifier,
                                      RazorpayProperties razorpayProperties, ObjectMapper objectMapper) {
        this.paymentOrderService = paymentOrderService;
        this.signatureVerifier = signatureVerifier;
        this.razorpayProperties = razorpayProperties;
        this.objectMapper = objectMapper;
    }

    @PostMapping("/api/v1/webhooks/razorpay")
    public ResponseEntity<Void> handle(@RequestBody String rawBody,
                                        @RequestHeader(value = "X-Razorpay-Signature", required = false) String signature) {
        if (razorpayProperties.getWebhookSecret().isBlank()) {
            throw new UnsupportedOperationException(
                    "Razorpay webhook secret is not configured yet. See RazorpayProperties and docs/decisions.md.");
        }
        if (!signatureVerifier.isValid(rawBody, signature, razorpayProperties.getWebhookSecret())) {
            log.warn("Rejected Razorpay webhook with an invalid or missing signature");
            return ResponseEntity.badRequest().build();
        }

        try {
            JsonNode root = objectMapper.readTree(rawBody);
            String event = root.path("event").asText("");
            JsonNode paymentEntity = root.path("payload").path("payment").path("entity");
            String orderId = paymentEntity.path("order_id").asText(null);
            String paymentId = paymentEntity.path("id").asText(null);

            if (orderId == null || paymentId == null) {
                log.warn("Razorpay webhook event '{}' missing order/payment id -- ignoring", event);
                return ResponseEntity.ok().build();
            }

            boolean captured = "payment.captured".equals(event);
            paymentOrderService.handleWebhookPayload(orderId, paymentId, captured);
        } catch (Exception e) {
            log.error("Failed to process Razorpay webhook payload", e);
            // Still 200 -- a malformed/unexpected payload shouldn't make Razorpay retry forever.
        }

        return ResponseEntity.ok().build();
    }
}
