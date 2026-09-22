package com.pgplatform.payment.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record DirectPaymentSubmitRequest(
        @NotBlank @Size(max = 100) String idempotencyKey,
        @JsonAlias("utr") @NotBlank @Size(max = 100)
        @Pattern(regexp = "^[A-Za-z0-9._/-]{6,100}$", message = "must be a valid transaction reference")
        String transactionReference,
        @AssertTrue(message = "must confirm that payment was completed") boolean paymentConfirmed
) {
}
