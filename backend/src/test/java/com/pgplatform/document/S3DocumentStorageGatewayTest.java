package com.pgplatform.document;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThatCode;

class S3DocumentStorageGatewayTest {

    @Test
    void cloudflareR2ConfigurationBuildsTheClientAndPresigner() {
        S3StorageProperties properties = new S3StorageProperties();
        properties.setEnabled(true);
        properties.setEndpoint("https://example-account.r2.cloudflarestorage.com");
        properties.setRegion("auto");
        properties.setBucket("hi-pg-kyc-private");
        properties.setAccessKey("0123456789abcdef0123456789abcdef");
        properties.setSecretKey("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef");
        properties.setPathStyleAccess(false);

        assertThatCode(() -> {
            S3DocumentStorageGateway gateway = new S3DocumentStorageGateway(properties);
            gateway.close();
        }).doesNotThrowAnyException();
    }
}
