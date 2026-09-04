package com.pgplatform.document;

import org.springframework.stereotype.Component;

import java.time.Duration;

/**
 * No object storage is provisioned yet (technical plan §7 item 1 -- flagged
 * as a gap, never resolved). Every method fails loudly and specifically
 * rather than silently no-opping, so an upload attempt surfaces as a clear
 * 501 (see GlobalExceptionHandler's UnsupportedOperationException handler)
 * instead of a mysterious empty success. Replace this whole class with a
 * real S3-backed implementation once a bucket + credentials exist -- see
 * infra/.env.example's S3_* placeholders and docs/decisions.md.
 */
@Component
public class StubDocumentStorageGateway implements DocumentStorageGateway {

    private static final String NOT_CONFIGURED =
            "Object storage is not configured yet. See DocumentStorageGateway and docs/decisions.md.";

    @Override
    public String store(byte[] content, String fileName, String contentType) {
        throw new UnsupportedOperationException(NOT_CONFIGURED);
    }

    @Override
    public String generateSignedUrl(String storageKey, Duration ttl) {
        throw new UnsupportedOperationException(NOT_CONFIGURED);
    }

    @Override
    public void delete(String storageKey) {
        throw new UnsupportedOperationException(NOT_CONFIGURED);
    }
}
