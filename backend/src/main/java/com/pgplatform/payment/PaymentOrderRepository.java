package com.pgplatform.payment;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;
import java.math.BigDecimal;
import java.time.Instant;

public interface PaymentOrderRepository extends JpaRepository<PaymentOrder, UUID> {
    Optional<PaymentOrder> findByIdAndDeletedAtIsNull(UUID id);
    Optional<PaymentOrder> findByIdempotencyKeyAndDeletedAtIsNull(String idempotencyKey);
    Optional<PaymentOrder> findByRazorpayOrderIdAndDeletedAtIsNull(String razorpayOrderId);
    Optional<PaymentOrder> findByRazorpayPaymentIdAndDeletedAtIsNull(String razorpayPaymentId);
    Optional<PaymentOrder> findFirstByBookingIdAndStatusAndDeletedAtIsNullOrderByCreatedAtDesc(
            UUID bookingId, PaymentOrderStatus status);
    Optional<PaymentOrder> findFirstByBookingIdAndStatusInAndDeletedAtIsNullOrderByCreatedAtDesc(
            UUID bookingId, java.util.Collection<PaymentOrderStatus> statuses);
    Optional<PaymentOrder> findFirstByFeeIdAndStatusAndDeletedAtIsNullOrderByCreatedAtDesc(
            UUID feeId, PaymentOrderStatus status);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from PaymentOrder p where p.id = :id and p.deletedAt is null")
    Optional<PaymentOrder> findByIdForUpdate(@Param("id") UUID id);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from PaymentOrder p where p.razorpayOrderId = :razorpayOrderId and p.deletedAt is null")
    Optional<PaymentOrder> findByRazorpayOrderIdForUpdate(@Param("razorpayOrderId") String razorpayOrderId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from PaymentOrder p where p.razorpayPaymentId = :razorpayPaymentId and p.deletedAt is null")
    Optional<PaymentOrder> findByRazorpayPaymentIdForUpdate(@Param("razorpayPaymentId") String razorpayPaymentId);

    @Query("select coalesce(sum(p.amount), 0) from PaymentOrder p " +
            "where p.booking.pg.owner.id = :ownerId and p.purpose = 'BOOKING' and p.status = 'PAID' " +
            "and p.paidAt >= :from and p.paidAt < :to and p.deletedAt is null")
    BigDecimal sumPaidBookingOrdersForOwner(@Param("ownerId") UUID ownerId,
                                            @Param("from") Instant from, @Param("to") Instant to);

    @Query("select coalesce(sum(p.amount), 0) from PaymentOrder p " +
            "where p.booking.pg.id = :pgId and p.purpose = 'BOOKING' and p.status = 'PAID' " +
            "and p.paidAt >= :from and p.paidAt < :to and p.deletedAt is null")
    BigDecimal sumPaidBookingOrdersForPg(@Param("pgId") UUID pgId,
                                         @Param("from") Instant from, @Param("to") Instant to);
}
