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
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Auto-generated the moment a Payment is recorded (technical plan §6 Phase
 * 7b: "receipts, generated from Fee/Payment records, genuinely depends on
 * Phase 5 being done"). There is no manual "create a receipt" endpoint --
 * that would let a receipt exist without a matching payment.
 *
 * Deliberately a snapshot (student/PG name, amount, period copied in at
 * issue time) rather than always joining live through payment -> fee ->
 * student/pg: a receipt is a historical document and must keep reading the
 * same even if the student's name is later corrected or -- once a "transfer
 * a student between PGs" feature exists -- the fee's denormalized pg_id
 * changes (see ADR-0008).
 */
@Getter
@Setter
@Entity
@Table(name = "receipts")
public class Receipt extends BaseEntity {

    @Column(name = "receipt_number", nullable = false, unique = true)
    private String receiptNumber;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "payment_id", nullable = false, unique = true)
    private Payment payment;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "student_id", nullable = false)
    private Student student;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "pg_id", nullable = false)
    private Pg pg;

    @Column(name = "student_name_snapshot", nullable = false)
    private String studentNameSnapshot;

    @Column(name = "pg_name_snapshot", nullable = false)
    private String pgNameSnapshot;

    @Column(name = "fee_period_month", nullable = false)
    private Integer feePeriodMonth;

    @Column(name = "fee_period_year", nullable = false)
    private Integer feePeriodYear;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal amount;

    @Column(name = "paid_on", nullable = false)
    private LocalDate paidOn;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private PaymentMethod method;
}
