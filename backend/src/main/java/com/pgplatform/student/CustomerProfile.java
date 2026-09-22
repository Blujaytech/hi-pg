package com.pgplatform.student;

import com.pgplatform.auth.User;
import com.pgplatform.common.BaseEntity;
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

@Getter
@Setter
@Entity
@Table(name = "customer_profiles")
public class CustomerProfile extends BaseEntity {
    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    @Column(name = "full_name", nullable = false)
    private String fullName;

    @Column(length = 120)
    private String occupation;

    @Column(name = "permanent_address", columnDefinition = "text")
    private String permanentAddress;

    @Enumerated(EnumType.STRING)
    @Column(name = "identity_type", length = 24)
    private IdentityType identityType;

    /** Only a masked reference is retained; the application never accepts a full Aadhaar number. */
    @Column(name = "identity_last_four", length = 4)
    private String identityLastFour;
}
