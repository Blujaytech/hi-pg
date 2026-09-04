package com.pgplatform.complaint;

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

import java.time.Instant;

/**
 * Technical plan §6 Phase 6. Owner-side only for now: logged on a student's
 * behalf by the owner, same as the rest of the owner console. Student
 * self-service filing (a logged-in Student user raising their own complaint)
 * is deferred until a Student login can be linked to a Student *record* --
 * see docs/decisions.md. `pg` is denormalized off `student.pg`, same
 * rationale/caveat as `Fee.pg` (ADR-0008).
 */
@Getter
@Setter
@Entity
@Table(name = "complaints")
public class Complaint extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "student_id", nullable = false)
    private Student student;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "pg_id", nullable = false)
    private Pg pg;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ComplaintCategory category;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private ComplaintPriority priority = ComplaintPriority.MEDIUM;

    @Column(nullable = false, columnDefinition = "text")
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private ComplaintStatus status = ComplaintStatus.OPEN;

    @Column(name = "resolution_notes", columnDefinition = "text")
    private String resolutionNotes;

    @Column(name = "resolved_at")
    private Instant resolvedAt;
}
