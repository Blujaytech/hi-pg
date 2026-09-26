package com.pgplatform.student.dto;

import com.pgplatform.student.CustomerIdentityDocument;
import com.pgplatform.student.IdentityType;

import java.time.Instant;
import java.util.UUID;

public record CustomerIdentityDocumentResponse(
        UUID id,
        IdentityType identityType,
        String fileName,
        String contentType,
        long sizeBytes,
        Instant uploadedAt
) {
    public static CustomerIdentityDocumentResponse from(CustomerIdentityDocument document) {
        if (document == null) return null;
        return new CustomerIdentityDocumentResponse(document.getId(), document.getIdentityType(),
                document.getFileName(), document.getContentType(), document.getSizeBytes(),
                document.getCreatedAt());
    }
}
