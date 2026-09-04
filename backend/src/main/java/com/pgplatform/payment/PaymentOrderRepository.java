package com.pgplatform.payment;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface PaymentOrderRepository extends JpaRepository<PaymentOrder, UUID> {
    Optional<PaymentOrder> findByIdempotencyKeyAndDeletedAtIsNull(String idempotencyKey);
    Optional<PaymentOrder> findByRazorpayOrderIdAndDeletedAtIsNull(String razorpayOrderId);
}
