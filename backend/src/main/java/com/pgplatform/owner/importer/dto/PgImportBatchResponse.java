package com.pgplatform.owner.importer.dto;

import com.pgplatform.owner.importer.PgImportBatchStatus;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record PgImportBatchResponse(
        UUID id,
        String fileName,
        String sourceSheet,
        PgImportBatchStatus status,
        int totalRows,
        int publishableRows,
        int warningRows,
        int invalidRows,
        int duplicateRows,
        int validMobileRows,
        int publishedRows,
        int invitedRows,
        int skippedRows,
        Instant createdAt,
        Instant completedAt,
        List<PgImportRowResponse> rows
) { }
