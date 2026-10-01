package com.pgplatform.payment.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.pgplatform.payment.DirectPaymentMethod;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record DirectPaymentSubmitRequest(
        @NotBlank @Size(max = 100) String idempotencyKey,
        DirectPaymentMethod paymentMethod,
        @JsonAlias("utr") @Size(max = 100)
        String transactionReference,
        @AssertTrue(message = "must confirm that payment was completed") boolean paymentConfirmed
) {
    public DirectPaymentSubmitRequest(String idempotencyKey, String transactionReference,
                                      boolean paymentConfirmed) {
        this(idempotencyKey, DirectPaymentMethod.UPI, transactionReference, paymentConfirmed);
    }
}
