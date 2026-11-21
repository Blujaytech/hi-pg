package com.pgplatform.owner.importer;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface PgImportRowRepository extends JpaRepository<PgImportRow, UUID> {
    List<PgImportRow> findAllByBatchIdAndDeletedAtIsNullOrderBySourceRowNumber(UUID batchId);
}
