package com.pgplatform.student;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface CustomerIdentityDocumentRepository extends JpaRepository<CustomerIdentityDocument, UUID> {
    Optional<CustomerIdentityDocument> findByProfileIdAndDeletedAtIsNull(UUID profileId);
    Optional<CustomerIdentityDocument> findByIdAndDeletedAtIsNull(UUID id);
}
