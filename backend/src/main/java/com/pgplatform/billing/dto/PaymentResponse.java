package com.pgplatform.billing.dto;

import com.pgplatform.billing.Payment;
import com.pgplatform.billing.PaymentMethod;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record PaymentResponse(
        UUID id,
        UUID feeId,
        BigDecimal amountPaid,
        LocalDate paidOn,
        PaymentMethod method,
        String reference,
        String note
) {
    public static PaymentResponse from(Payment payment) {
        return new PaymentResponse(payment.getId(), payment.getFee().getId(), payment.getAmountPaid(),
                payment.getPaidOn(), payment.getMethod(), payment.getReference(), payment.getNote());
    }
}
