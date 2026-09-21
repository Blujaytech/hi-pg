package com.pgplatform.payment;

import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.http.MediaType;
import org.springframework.web.client.RestClient;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Direct server-to-server integration using Razorpay's documented REST APIs. */
public class HttpRazorpayGateway implements RazorpayGateway {

    private final RestClient client;

    public HttpRazorpayGateway(RazorpayProperties properties) {
        this.client = RestClient.builder()
                .baseUrl(properties.getApiBaseUrl())
                .defaultHeaders(headers -> headers.setBasicAuth(properties.getKeyId(), properties.getKeySecret()))
                .build();
    }

    @Override
    public RazorpayOrderResult createOrder(BigDecimal amount, String currency, String receipt) {
        JsonNode response = post("/v1/orders", Map.of(
                "amount", toSubunits(amount),
                "currency", currency,
                "receipt", receipt,
                "partial_payment", false
        ));
        return new RazorpayOrderResult(requiredText(response, "id"));
    }

    @Override
    public RazorpayTransferResult createTransfer(String paymentId, String linkedAccountId, BigDecimal amount,
                                                  boolean onHold, Long onHoldUntilEpochSeconds, String reference) {
        Map<String, Object> transfer = new LinkedHashMap<>();
        transfer.put("account", linkedAccountId);
        transfer.put("amount", toSubunits(amount));
        transfer.put("currency", "INR");
        transfer.put("on_hold", onHold);
        if (onHold && onHoldUntilEpochSeconds != null) {
            transfer.put("on_hold_until", onHoldUntilEpochSeconds);
        }
        transfer.put("notes", Map.of("reference", reference));

        JsonNode response = post("/v1/payments/" + paymentId + "/transfers", Map.of("transfers", List.of(transfer)));
        JsonNode entity = response.path("items").isArray() && !response.path("items").isEmpty()
                ? response.path("items").get(0) : response;
        return new RazorpayTransferResult(requiredText(entity, "id"), entity.path("status").asText("pending"),
                entity.path("on_hold").asBoolean(onHold));
    }

    @Override
    public RazorpaySubscriptionResult createMonthlySubscription(BigDecimal amount, String description,
                                                                 long startAtEpochSeconds, int totalCount) {
        JsonNode plan = post("/v1/plans", Map.of(
                "period", "monthly",
                "interval", 1,
                "item", Map.of(
                        "name", description,
                        "amount", toSubunits(amount),
                        "currency", "INR",
                        "description", description
                )
        ));
        String planId = requiredText(plan, "id");
        JsonNode subscription = post("/v1/subscriptions", Map.of(
                "plan_id", planId,
                "total_count", totalCount,
                "quantity", 1,
                "customer_notify", true,
                "start_at", startAtEpochSeconds,
                "notes", Map.of("source", "hi-pg-monthly-rent")
        ));
        return new RazorpaySubscriptionResult(planId, requiredText(subscription, "id"),
                subscription.path("short_url").asText(null));
    }

    @Override
    public RazorpayRefundResult refund(String paymentId, BigDecimal amount, String reference) {
        JsonNode response = post("/v1/payments/" + paymentId + "/refund", Map.of(
                "amount", toSubunits(amount),
                "notes", Map.of("reference", reference)
        ));
        return new RazorpayRefundResult(requiredText(response, "id"), response.path("status").asText("pending"));
    }

    @Override
    public boolean isPaymentCaptured(String paymentId) {
        JsonNode response = client.get()
                .uri("/v1/payments/{id}", paymentId)
                .retrieve()
                .body(JsonNode.class);
        return response != null && "captured".equalsIgnoreCase(response.path("status").asText());
    }

    private JsonNode post(String uri, Object body) {
        JsonNode response = client.post()
                .uri(uri)
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .body(JsonNode.class);
        if (response == null) {
            throw new IllegalStateException("Razorpay returned an empty response");
        }
        return response;
    }

    private long toSubunits(BigDecimal amount) {
        return amount.movePointRight(2).setScale(0, RoundingMode.UNNECESSARY).longValueExact();
    }

    private String requiredText(JsonNode node, String field) {
        String value = node.path(field).asText(null);
        if (value == null || value.isBlank()) {
            throw new IllegalStateException("Razorpay response did not contain " + field);
        }
        return value;
    }
}
