package com.pgplatform.owner;

import com.pgplatform.auth.User;
import com.pgplatform.common.BaseEntity;
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

/** Top of the Owner hierarchy: PG -> Floor -> Room -> Bed (§2/§6 Phase 2 of the technical plan). */
@Getter
@Setter
@Entity
@Table(name = "pgs")
public class Pg extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "owner_id", nullable = false)
    private User owner;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private String address;

    @Column(nullable = false)
    private String city;

    private String state;

    private String pincode;

    private Double latitude;

    private Double longitude;

    @Column(columnDefinition = "text")
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(name = "gender_preference", nullable = false, length = 20)
    private GenderPreference genderPreference = GenderPreference.CO_ED;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private PgStatus status = PgStatus.ACTIVE;
}
