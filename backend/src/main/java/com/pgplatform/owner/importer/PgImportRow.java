package com.pgplatform.owner.importer;

import com.pgplatform.common.BaseEntity;
import com.pgplatform.owner.GenderPreference;
import com.pgplatform.owner.Pg;
import com.pgplatform.owner.PgInvitationStatus;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(name = "pg_import_rows")
public class PgImportRow extends BaseEntity {
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "batch_id", nullable = false)
    private PgImportBatch batch;

    @Column(name = "source_row_number", nullable = false)
    private int sourceRowNumber;
    private String name;
    private String ownerName;
    private String ownerMobile;
    private String address;
    private String city;
    private String state;
    private String pincode;
    private Double latitude;
    private Double longitude;
    private String locationUrl;
    private String properLocality;
    private String originalStayType;

    @Column(name = "image_count", nullable = false)
    private int imageCount;

    @Enumerated(EnumType.STRING)
    private GenderPreference genderPreference;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 24)
    private PgImportValidationStatus validationStatus;

    @Column(columnDefinition = "text")
    private String validationMessages;

    @Column(length = 1000)
    private String dedupeKey;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 24)
    private PgImportPublishStatus publishStatus = PgImportPublishStatus.PENDING;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 24)
    private PgInvitationStatus invitationStatus = PgInvitationStatus.NOT_SENT;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "published_pg_id")
    private Pg publishedPg;
}
