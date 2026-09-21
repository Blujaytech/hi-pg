package com.pgplatform.autopay.dto;

import com.pgplatform.autopay.AutoPayMandate;
import com.pgplatform.autopay.AutoPayStatus;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record AutoPayResponse(
        UUID id,
        BigDecimal amount,
        Integer dueDay,
        AutoPayStatus status,
        LocalDate nextChargeDate,
        String razorpaySubscriptionId,
        String authorizationUrl,
        String razorpayKeyId,
        String failureReason
) {
    public static AutoPayResponse from(AutoPayMandate mandate, String authorizationUrl, String keyId) {
        return new AutoPayResponse(mandate.getId(), mandate.getAmount(), mandate.getDueDay(), mandate.getStatus(),
                mandate.getNextChargeDate(), mandate.getRazorpaySubscriptionId(), authorizationUrl, keyId,
                mandate.getFailureReason());
    }
}
