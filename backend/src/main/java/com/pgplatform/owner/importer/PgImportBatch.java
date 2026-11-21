package com.pgplatform.owner.importer;

import com.pgplatform.common.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Getter
@Setter
@Entity
@Table(name = "pg_import_batches")
public class PgImportBatch extends BaseEntity {
    @Column(name = "file_name", nullable = false)
    private String fileName;

    @Column(name = "file_sha256", nullable = false, unique = true, length = 64)
    private String fileSha256;

    @Column(name = "source_sheet", nullable = false)
    private String sourceSheet;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 24)
    private PgImportBatchStatus status = PgImportBatchStatus.PREVIEW_READY;

    private int totalRows;
    private int publishableRows;
    private int warningRows;
    private int invalidRows;
    private int duplicateRows;
    private int validMobileRows;
    private int publishedRows;
    private int invitedRows;
    private int skippedRows;
    private Instant completedAt;
}
