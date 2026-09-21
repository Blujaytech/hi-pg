package com.pgplatform.payment;

import com.pgplatform.billing.Fee;
import com.pgplatform.booking.Booking;
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

import java.math.BigDecimal;

/**
 * Tracks one attempt to pay a Fee online via Razorpay (technical plan §6
 * Phase 12, §7 item 4: idempotent payments need a concrete mechanism, not
 * just a principle). {@code idempotencyKey} is client-generated (one per
 * payment attempt) and unique at the DB level -- retrying the same attempt
 * (e.g. after a dropped network response) returns the same order instead of
 * creating a duplicate charge. See PaymentOrderService and
 * docs/decisions.md ADR-0019.
 */
@Getter
@Setter
@Entity
@Table(name = "payment_orders")
public class PaymentOrder extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "fee_id")
    private Fee fee;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "booking_id")
    private Booking booking;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 24)
    private PaymentPurpose purpose = PaymentPurpose.FEE;

    @Column(name = "idempotency_key", nullable = false, unique = true, length = 100)
    private String idempotencyKey;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal amount;

    @Column(nullable = false, length = 3)
    private String currency = "INR";

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private PaymentOrderStatus status = PaymentOrderStatus.CREATED;

    @Column(name = "razorpay_order_id", unique = true, length = 100)
    private String razorpayOrderId;

    @Column(name = "razorpay_payment_id", unique = true, length = 100)
    private String razorpayPaymentId;

    @Column(name = "failure_reason", columnDefinition = "text")
    private String failureReason;

    @Column(name = "razorpay_transfer_id", unique = true, length = 100)
    private String razorpayTransferId;

    @Enumerated(EnumType.STRING)
    @Column(name = "transfer_status", nullable = false, length = 24)
    private TransferStatus transferStatus = TransferStatus.NOT_CREATED;

    @Column(name = "owner_amount", precision = 10, scale = 2)
    private BigDecimal ownerAmount;

    @Column(name = "razorpay_refund_id", unique = true, length = 100)
    private String razorpayRefundId;
}
