package com.pgplatform.onboarding;

import com.pgplatform.common.BaseEntity;
import com.pgplatform.owner.Pg;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Getter
@Setter
@Entity
@Table(name = "owner_kyc_submissions")
public class OwnerKycSubmission extends BaseEntity {
    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "pg_id", nullable = false, unique = true)
    private Pg pg;
    @Column(name = "legal_name", nullable = false)
    private String legalName;
    @Column(name = "pan_last_four", nullable = false, length = 4)
    private String panLastFour;
    @Column(name = "aadhaar_last_four", nullable = false, length = 4)
    private String aadhaarLastFour;
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private OwnerKycStatus status = OwnerKycStatus.DRAFT;
    @Column(name = "review_note", columnDefinition = "text")
    private String reviewNote;
    @Column(name = "submitted_at")
    private Instant submittedAt;
    @Column(name = "reviewed_at")
    private Instant reviewedAt;
}
