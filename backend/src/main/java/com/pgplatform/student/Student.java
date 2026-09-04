package com.pgplatform.student;

import com.pgplatform.auth.User;
import com.pgplatform.common.BaseEntity;
import com.pgplatform.owner.Bed;
import com.pgplatform.owner.Pg;
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

import java.time.LocalDate;

/**
 * Owner-managed student record (technical plan §6 Phase 4: "add/view students
 * manually, independent of booking flow"). Historically NOT tied to a
 * login/User -- a student can still exist here without ever creating an
 * account (owner-added-manually is still supported). Phase 11 added the
 * optional {@code user} link: a self-service booking either creates a new
 * Student row for the logged-in Student user, or (not implemented yet)
 * could claim an existing owner-added one -- see BookingService and
 * docs/decisions.md.
 */
@Getter
@Setter
@Entity
@Table(name = "students")
public class Student extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "pg_id", nullable = false)
    private Pg pg;

    /** Null for an owner-added student who has never signed in. Unique when set -- one login maps to at most one Student record. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", unique = true)
    private User user;

    /** Null until assigned -- a student can be added before being placed in a bed. */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "bed_id")
    private Bed bed;

    @Column(name = "full_name", nullable = false)
    private String fullName;

    @Column(nullable = false)
    private String phone;

    private String email;

    @Column(name = "guardian_name")
    private String guardianName;

    @Column(name = "guardian_phone")
    private String guardianPhone;

    @Column(name = "permanent_address", columnDefinition = "text")
    private String permanentAddress;

    /**
     * Aadhaar or other government ID number. Stored as plain text for now --
     * this is a known gap, not an oversight: real document storage /
     * encryption-at-rest for PII lands with Phase 7 (Documents). Do not add
     * more sensitive fields here without revisiting docs/security.md first.
     */
    @Column(name = "id_proof_number")
    private String idProofNumber;

    @Column(name = "date_of_joining", nullable = false)
    private LocalDate dateOfJoining;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private StudentStatus status = StudentStatus.ACTIVE;

    @Column(name = "move_out_date")
    private LocalDate moveOutDate;
}
