package com.pgplatform.owner;

import com.pgplatform.common.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
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
@Table(name = "pg_direct_payment_settings")
public class PgDirectPaymentSettings extends BaseEntity {
    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "pg_id", nullable = false, unique = true)
    private Pg pg;

    @Column(nullable = false)
    private boolean enabled;

    @Column(name = "beneficiary_name", nullable = false)
    private String beneficiaryName;

    @Column(name = "upi_id", nullable = false, length = 320)
    private String upiId;

    @Column(name = "mobile_number", nullable = false, length = 20)
    private String mobileNumber;

    @Column(nullable = false)
    private boolean verified;

    @Column(name = "verified_at")
    private Instant verifiedAt;
}
