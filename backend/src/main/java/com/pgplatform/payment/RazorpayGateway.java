package com.pgplatform.payment;

import java.math.BigDecimal;

/**
 * The one call this whole phase actually needs Razorpay credentials for.
 * Everything else (idempotency bookkeeping, webhook signature verification,
 * recording the resulting Payment against a Fee) works today and is tested
 * today -- only this outbound call is stubbed. See StubRazorpayGateway and
 * docs/decisions.md ADR-0019.
 */
public interface RazorpayGateway {
    RazorpayOrderResult createOrder(BigDecimal amount, String currency, String receipt);
}
