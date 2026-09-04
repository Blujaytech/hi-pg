package com.pgplatform.payment;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Pure unit test -- no Spring context, no database. Proves the HMAC
 * verification logic itself is correct, independent of whether a real
 * Razorpay account exists (see docs/decisions.md ADR-0019).
 */
class RazorpaySignatureVerifierTest {

    private final RazorpaySignatureVerifier verifier = new RazorpaySignatureVerifier();

    @Test
    void acceptsASignatureComputedTheSameWayRazorpayWould() {
        String body = "{\"event\":\"payment.captured\"}";
        String secret = "whsec_test_123";
        String signature = verifier.computeSignature(body, secret);

        assertThat(verifier.isValid(body, signature, secret)).isTrue();
    }

    @Test
    void rejectsATamperedBody() {
        String secret = "whsec_test_123";
        String signature = verifier.computeSignature("{\"event\":\"payment.captured\"}", secret);

        assertThat(verifier.isValid("{\"event\":\"payment.failed\"}", signature, secret)).isFalse();
    }

    @Test
    void rejectsTheWrongSecret() {
        String body = "{\"event\":\"payment.captured\"}";
        String signature = verifier.computeSignature(body, "whsec_test_123");

        assertThat(verifier.isValid(body, signature, "whsec_different")).isFalse();
    }

    @Test
    void rejectsWhenSecretOrSignatureIsMissing() {
        assertThat(verifier.isValid("body", "sig", "")).isFalse();
        assertThat(verifier.isValid("body", null, "secret")).isFalse();
        assertThat(verifier.isValid("body", "", "secret")).isFalse();
    }
}
