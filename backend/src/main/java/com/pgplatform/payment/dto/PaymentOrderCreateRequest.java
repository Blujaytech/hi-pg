package com.pgplatform.payment.dto;

import jakarta.validation.constraints.NotBlank;

/** idempotencyKey: client-generated once per payment attempt (e.g. a UUID), reused verbatim on retry. */
public record PaymentOrderCreateRequest(@NotBlank String idempotencyKey) {
}
