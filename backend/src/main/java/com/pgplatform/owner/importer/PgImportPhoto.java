package com.pgplatform.owner.importer;

import com.pgplatform.common.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(name = "pg_import_photos")
public class PgImportPhoto extends BaseEntity {
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "import_row_id", nullable = false)
    private PgImportRow importRow;

    @Column(name = "original_file_name", nullable = false)
    private String originalFileName;

    @Column(name = "content_type", nullable = false, length = 100)
    private String contentType;

    @Column(name = "file_size", nullable = false)
    private long fileSize;

    @Column(name = "display_order", nullable = false)
    private int displayOrder;

    @Column(columnDefinition = "bytea")
    private byte[] content;

    @Column(name = "storage_key", length = 500)
    private String storageKey;
}
