package com.pgplatform.payment.dto;

import com.pgplatform.payment.PaymentOrder;
import com.pgplatform.payment.PaymentOrderStatus;
import com.pgplatform.payment.PaymentPurpose;
import com.pgplatform.payment.TransferStatus;

import java.math.BigDecimal;
import java.util.UUID;

public record PaymentOrderResponse(
        UUID id,
        UUID feeId,
        UUID bookingId,
        PaymentPurpose purpose,
        BigDecimal amount,
        String currency,
        PaymentOrderStatus status,
        String razorpayOrderId,
        String razorpayKeyId,
        TransferStatus transferStatus
) {
    public static PaymentOrderResponse from(PaymentOrder order, String razorpayKeyId) {
        return new PaymentOrderResponse(order.getId(),
                order.getFee() == null ? null : order.getFee().getId(),
                order.getBooking() == null ? null : order.getBooking().getId(),
                order.getPurpose(), order.getAmount(), order.getCurrency(), order.getStatus(),
                order.getRazorpayOrderId(), razorpayKeyId, order.getTransferStatus());
    }
}
