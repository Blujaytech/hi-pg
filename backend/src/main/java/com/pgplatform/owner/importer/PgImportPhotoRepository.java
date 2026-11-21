package com.pgplatform.owner.importer;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface PgImportPhotoRepository extends JpaRepository<PgImportPhoto, UUID> {
    List<PgImportPhoto> findAllByImportRowIdInAndDeletedAtIsNullOrderByImportRowSourceRowNumberAscDisplayOrderAsc(
            List<UUID> importRowIds);
}
