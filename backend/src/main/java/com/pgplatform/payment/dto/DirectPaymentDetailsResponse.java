package com.pgplatform.payment.dto;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record DirectPaymentDetailsResponse(
        UUID bookingId,
        String ownerName,
        String upiId,
        String maskedMobile,
        BigDecimal amount,
        String currency,
        String upiUri,
        Instant paymentHoldExpiresAt
) {
}
