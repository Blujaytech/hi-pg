package com.pgplatform.owner.importer;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PgImportBatchRepository extends JpaRepository<PgImportBatch, UUID> {
    Optional<PgImportBatch> findByFileSha256AndDeletedAtIsNull(String fileSha256);
    List<PgImportBatch> findAllByDeletedAtIsNullOrderByCreatedAtDesc();

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<PgImportBatch> findLockedByIdAndDeletedAtIsNull(UUID id);
}
