package com.pgplatform.document;

import com.pgplatform.common.BaseEntity;
import com.pgplatform.owner.Pg;
import com.pgplatform.student.Student;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

/**
 * Metadata only -- technical plan §7 item 1 flags object storage as an
 * unspecified gap, and it's still unresolved (see docs/decisions.md). This
 * table and the upload/list/delete plumbing around it are real and wired up;
 * the one thing that doesn't work yet is actually writing bytes anywhere,
 * because {@link DocumentStorageGateway} has no real implementation until an
 * S3-compatible bucket + credentials exist. `storageKey` stays null until
 * then. This mirrors how Google OAuth is stubbed (GoogleAuthService) rather
 * than left entirely unbuilt.
 */
@Getter
@Setter
@Entity
@Table(name = "documents")
public class Document extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "student_id", nullable = false)
    private Student student;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "pg_id", nullable = false)
    private Pg pg;

    @Enumerated(EnumType.STRING)
    @Column(name = "document_type", nullable = false, length = 20)
    private DocumentType documentType;

    @Column(name = "file_name", nullable = false)
    private String fileName;

    @Column(name = "content_type", nullable = false)
    private String contentType;

    @Column(name = "size_bytes", nullable = false)
    private long sizeBytes;

    /** Object key in whatever bucket ends up backing DocumentStorageGateway. Null until real storage exists -- today, every upload fails before a row would even get this far (see DocumentService.upload). */
    @Column(name = "storage_key")
    private String storageKey;
}
