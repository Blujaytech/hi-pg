package com.pgplatform.document.dto;

import com.pgplatform.document.Document;
import com.pgplatform.document.DocumentType;

import java.time.Instant;
import java.util.UUID;

public record DocumentResponse(
        UUID id,
        UUID studentId,
        DocumentType documentType,
        String fileName,
        String contentType,
        long sizeBytes,
        Instant uploadedAt
) {
    public static DocumentResponse from(Document document) {
        return new DocumentResponse(
                document.getId(),
                document.getStudent().getId(),
                document.getDocumentType(),
                document.getFileName(),
                document.getContentType(),
                document.getSizeBytes(),
                document.getCreatedAt()
        );
    }
}
