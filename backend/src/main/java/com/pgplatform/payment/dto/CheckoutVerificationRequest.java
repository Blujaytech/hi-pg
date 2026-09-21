package com.pgplatform.payment.dto;

import jakarta.validation.constraints.NotBlank;

public record CheckoutVerificationRequest(
        @NotBlank String razorpayPaymentId,
        @NotBlank String razorpaySignature
) {
}
