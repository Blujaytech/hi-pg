package com.pgplatform.payment;

import com.pgplatform.auth.User;
import com.pgplatform.booking.Booking;
import com.pgplatform.common.BaseEntity;
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

import java.math.BigDecimal;
import java.time.Instant;

@Getter
@Setter
@Entity
@Table(name = "direct_payment_requests")
public class DirectPaymentRequest extends BaseEntity {
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "booking_id", nullable = false)
    private Booking booking;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "pg_id", nullable = false)
    private Pg pg;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "customer_user_id", nullable = false)
    private User customer;

    @Column(name = "idempotency_key", nullable = false, unique = true, length = 100)
    private String idempotencyKey;

    @Column(name = "quoted_amount", nullable = false, precision = 10, scale = 2, updatable = false)
    private BigDecimal quotedAmount;

    @Column(nullable = false, length = 3, updatable = false)
    private String currency = "INR";

    @Column(name = "transaction_reference", nullable = false, length = 100, updatable = false)
    private String transactionReference;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 24)
    private DirectPaymentStatus status = DirectPaymentStatus.PENDING;

    @Column(name = "submitted_at", nullable = false, updatable = false)
    private Instant submittedAt;

    @Column(name = "review_due_at", nullable = false, updatable = false)
    private Instant reviewDueAt;

    @Column(name = "beneficiary_name_snapshot", nullable = false, updatable = false)
    private String beneficiaryNameSnapshot;

    @Column(name = "upi_id_snapshot", nullable = false, length = 320, updatable = false)
    private String upiIdSnapshot;

    @Column(name = "mobile_number_snapshot", nullable = false, length = 20, updatable = false)
    private String mobileNumberSnapshot;

    @Column(name = "confirmed_amount", precision = 10, scale = 2)
    private BigDecimal confirmedAmount;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reviewed_by")
    private User reviewedBy;

    @Column(name = "reviewed_at")
    private Instant reviewedAt;

    @Column(name = "decision_idempotency_key", unique = true, length = 100)
    private String decisionIdempotencyKey;

    @Column(name = "review_note", columnDefinition = "text")
    private String reviewNote;

    @Column(name = "rejection_reason", columnDefinition = "text")
    private String rejectionReason;
}
