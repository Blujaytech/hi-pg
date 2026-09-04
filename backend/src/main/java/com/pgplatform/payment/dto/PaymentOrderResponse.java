package com.pgplatform.payment.dto;

import com.pgplatform.payment.PaymentOrder;
import com.pgplatform.payment.PaymentOrderStatus;

import java.math.BigDecimal;
import java.util.UUID;

public record PaymentOrderResponse(
        UUID id,
        UUID feeId,
        BigDecimal amount,
        String currency,
        PaymentOrderStatus status,
        String razorpayOrderId
) {
    public static PaymentOrderResponse from(PaymentOrder order) {
        return new PaymentOrderResponse(order.getId(), order.getFee().getId(), order.getAmount(),
                order.getCurrency(), order.getStatus(), order.getRazorpayOrderId());
    }
}
