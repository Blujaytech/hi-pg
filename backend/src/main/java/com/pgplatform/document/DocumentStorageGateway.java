package com.pgplatform.document;

import java.time.Duration;

/**
 * Abstraction over "put these bytes somewhere and let me get them back
 * later, privately" -- an S3-compatible object store, per the technical plan
 * §7 item 1 (never a public bucket; access via signed URL so Spring Boot
 * controls who can fetch a given document).
 *
 * {@link StubDocumentStorageGateway} is the only implementation right now
 * and deliberately fails loudly (see its javadoc) -- there is no S3
 * endpoint/bucket/credentials configured. When there is, add a real
 * implementation (e.g. using the AWS S3 SDK against any S3-compatible
 * endpoint) and switch the bean, without touching DocumentService or the
 * controller.
 */
public interface DocumentStorageGateway {
    /** @return the storage key the bytes were written under. */
    String store(byte[] content, String fileName, String contentType);

    /** @return a time-limited URL the owner's client can fetch the object from directly. */
    String generateSignedUrl(String storageKey, Duration ttl);

    void delete(String storageKey);
}
