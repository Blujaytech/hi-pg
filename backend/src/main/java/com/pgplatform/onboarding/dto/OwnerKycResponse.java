package com.pgplatform.onboarding.dto;

import com.pgplatform.onboarding.OwnerKycDocument;
import com.pgplatform.onboarding.OwnerKycDocumentType;
import com.pgplatform.onboarding.OwnerKycStatus;
import com.pgplatform.onboarding.OwnerKycSubmission;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record OwnerKycResponse(UUID id, UUID pgId, String pgName, String ownerName, String verifiedPhone,
                               String legalName, String panLastFour, String aadhaarLastFour,
                               OwnerKycStatus status, String reviewNote, Instant submittedAt,
                               List<DocumentSummary> documents) {
    public record DocumentSummary(UUID id, OwnerKycDocumentType type, String fileName,
                                  String contentType, Long sizeBytes) {
        public static DocumentSummary from(OwnerKycDocument document) {
            return new DocumentSummary(document.getId(), document.getDocumentType(), document.getFileName(),
                    document.getContentType(), document.getSizeBytes());
        }
    }

    public static OwnerKycResponse from(OwnerKycSubmission submission, List<OwnerKycDocument> documents) {
        return new OwnerKycResponse(submission.getId(), submission.getPg().getId(), submission.getPg().getName(),
                submission.getPg().getOwner().getFullName(), submission.getPg().getOwner().getPhone(),
                submission.getLegalName(), submission.getPanLastFour(), submission.getAadhaarLastFour(),
                submission.getStatus(), submission.getReviewNote(), submission.getSubmittedAt(),
                documents.stream().map(DocumentSummary::from).toList());
    }
}
