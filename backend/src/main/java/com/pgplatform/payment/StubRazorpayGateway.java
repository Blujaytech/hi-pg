package com.pgplatform.payment;

import java.math.BigDecimal;

/**
 * No Razorpay account is provisioned yet (no key id/secret configured --
 * see RazorpayProperties). Same pattern as Google OAuth (Phase 1) and
 * Document storage (Phase 7b): the real interface and every call site exist
 * now, but this implementation always fails loudly rather than faking
 * success or silently no-op'ing. Swap this bean out for a real HTTP-calling
 * implementation once RazorpayProperties.isConfigured() -- no other code
 * needs to change.
 */
public class StubRazorpayGateway implements RazorpayGateway {

    @Override
    public RazorpayOrderResult createOrder(BigDecimal amount, String currency, String receipt) {
        throw notConfigured();
    }

    @Override
    public RazorpayTransferResult createTransfer(String paymentId, String linkedAccountId, BigDecimal amount,
                                                  boolean onHold, Long onHoldUntilEpochSeconds, String reference) {
        throw notConfigured();
    }

    @Override
    public RazorpaySubscriptionResult createMonthlySubscription(BigDecimal amount, String description,
                                                                 long startAtEpochSeconds, int totalCount) {
        throw notConfigured();
    }

    @Override
    public RazorpayRefundResult refund(String paymentId, BigDecimal amount, String reference) {
        throw notConfigured();
    }

    @Override
    public boolean isPaymentCaptured(String paymentId) {
        throw notConfigured();
    }

    private UnsupportedOperationException notConfigured() {
        throw new UnsupportedOperationException(
                "Razorpay is not configured yet (no API key). See RazorpayGateway and docs/decisions.md.");
    }
}
