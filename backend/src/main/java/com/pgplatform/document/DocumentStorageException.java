package com.pgplatform.document;

/** A safe client-facing wrapper for private object-storage failures. */
public class DocumentStorageException extends RuntimeException {
    public DocumentStorageException(String message, Throwable cause) {
        super(message, cause);
    }
}
