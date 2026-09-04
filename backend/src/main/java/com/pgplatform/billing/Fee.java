package com.pgplatform.billing;

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

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * One billing period's rent charge for a student (technical plan §6 Phase 5).
 * `pg` is denormalized off `student.pg` purely so fee-list-for-a-PG and the
 * dashboard aggregates don't need to join through `students` -- keep it in
 * sync with `student.pg` if a student is ever moved between PGs (not
 * possible today; there's no such endpoint).
 */
@Getter
@Setter
@Entity
@Table(name = "fees")
public class Fee extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "student_id", nullable = false)
    private Student student;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "pg_id", nullable = false)
    private Pg pg;

    @Column(name = "period_month", nullable = false)
    private Integer periodMonth;

    @Column(name = "period_year", nullable = false)
    private Integer periodYear;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal amount;

    @Column(name = "due_date", nullable = false)
    private LocalDate dueDate;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private FeeStatus status = FeeStatus.PENDING;

    @Column(columnDefinition = "text")
    private String notes;
}
