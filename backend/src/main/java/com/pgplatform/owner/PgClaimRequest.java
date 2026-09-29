package com.pgplatform.owner;

import com.pgplatform.auth.User;
import com.pgplatform.common.BaseEntity;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Getter
@Setter
@Entity
@Table(name = "pg_claim_requests")
public class PgClaimRequest extends BaseEntity {
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "pg_id", nullable = false)
    private Pg pg;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "claimant_user_id", nullable = false)
    private User claimant;

    @Column(name = "matched_mobile", nullable = false, length = 20)
    private String matchedMobile;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private PgClaimRequestStatus status = PgClaimRequestStatus.PENDING;

    @Column(name = "review_note", columnDefinition = "text")
    private String reviewNote;

    @Column(name = "submitted_at", nullable = false)
    private Instant submittedAt = Instant.now();

    @Column(name = "reviewed_at")
    private Instant reviewedAt;
}
