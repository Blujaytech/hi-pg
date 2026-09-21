package com.pgplatform.payment.web;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.pgplatform.payment.PaymentOrderService;
import com.pgplatform.payment.RazorpayProperties;
import com.pgplatform.payment.RazorpaySignatureVerifier;
import com.pgplatform.autopay.AutoPayService;
import com.pgplatform.deposit.DepositService;
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
    private final AutoPayService autoPayService;
    private final DepositService depositService;

    public RazorpayWebhookController(PaymentOrderService paymentOrderService, RazorpaySignatureVerifier signatureVerifier,
                                      RazorpayProperties razorpayProperties, ObjectMapper objectMapper,
                                      AutoPayService autoPayService, DepositService depositService) {
        this.paymentOrderService = paymentOrderService;
        this.signatureVerifier = signatureVerifier;
        this.razorpayProperties = razorpayProperties;
        this.objectMapper = objectMapper;
        this.autoPayService = autoPayService;
        this.depositService = depositService;
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

        final JsonNode root;
        try {
            root = objectMapper.readTree(rawBody);
        } catch (JsonProcessingException e) {
            log.warn("Ignoring malformed Razorpay webhook payload", e);
            return ResponseEntity.badRequest().build();
        }

        String event = root.path("event").asText("");
        if (depositService.handleWebhook(event, root)) {
            return ResponseEntity.ok().build();
        }
        if (paymentOrderService.handleRefundWebhook(event, root)) {
            return ResponseEntity.ok().build();
        }
        if (autoPayService.handleWebhook(event, root)) {
            return ResponseEntity.ok().build();
        }
        if (!"payment.captured".equals(event) && !"payment.failed".equals(event)) {
            return ResponseEntity.ok().build();
        }

        JsonNode paymentEntity = root.path("payload").path("payment").path("entity");
        String orderId = paymentEntity.path("order_id").asText(null);
        String paymentId = paymentEntity.path("id").asText(null);
        if (orderId == null || paymentId == null) {
            log.warn("Razorpay webhook event '{}' missing order/payment id -- ignoring", event);
            return ResponseEntity.ok().build();
        }

        // Business-processing exceptions intentionally become 5xx so Razorpay retries.
        paymentOrderService.handleWebhookPayload(orderId, paymentId, "payment.captured".equals(event));
        return ResponseEntity.ok().build();
    }
}
