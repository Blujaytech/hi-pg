package com.pgplatform.onboarding;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface OwnerKycDocumentRepository extends JpaRepository<OwnerKycDocument, UUID> {
    List<OwnerKycDocument> findAllBySubmissionIdAndDeletedAtIsNullOrderByDocumentType(UUID submissionId);
    Optional<OwnerKycDocument> findBySubmissionIdAndDocumentTypeAndDeletedAtIsNull(
            UUID submissionId, OwnerKycDocumentType documentType);
    Optional<OwnerKycDocument> findByIdAndDeletedAtIsNull(UUID id);
}
