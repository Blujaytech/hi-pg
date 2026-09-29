package com.pgplatform.owner;

import com.pgplatform.common.BaseEntity;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Getter
@Setter
@Entity
@Table(name = "pg_owner_contacts")
public class PgOwnerContact extends BaseEntity {
    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "pg_id", nullable = false, unique = true)
    private Pg pg;

    @Column(name = "owner_name", length = 120)
    private String ownerName;

    @Column(name = "normalized_mobile", nullable = false, length = 20)
    private String normalizedMobile;

    @Enumerated(EnumType.STRING)
    @Column(name = "invitation_status", nullable = false, length = 24)
    private PgInvitationStatus invitationStatus = PgInvitationStatus.NOT_SENT;

    @Column(name = "invited_at")
    private Instant invitedAt;
}
