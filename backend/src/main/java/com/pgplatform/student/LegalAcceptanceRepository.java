package com.pgplatform.student;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface LegalAcceptanceRepository extends JpaRepository<LegalAcceptance, UUID> {
    boolean existsByUserIdAndDocumentTypeAndDocumentVersionAndDeletedAtIsNull(
            UUID userId, LegalDocumentType documentType, String documentVersion);

    Optional<LegalAcceptance> findFirstByUserIdAndDocumentTypeAndDeletedAtIsNullOrderByAcceptedAtDesc(
            UUID userId, LegalDocumentType documentType);
}
