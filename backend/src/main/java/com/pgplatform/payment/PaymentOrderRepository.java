package com.pgplatform.payment;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

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
}
