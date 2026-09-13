package com.pgplatform.auth;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

class GoogleApiIdentityVerifierTest {

    @Test
    void reportsAConfigurationErrorWhenTheServerClientIdIsMissing() {
        GoogleApiIdentityVerifier verifier = new GoogleApiIdentityVerifier("");

        assertThatThrownBy(() -> verifier.verify("any-token"))
                .isInstanceOf(UnsupportedOperationException.class)
                .hasMessageContaining("not configured");
    }
}
