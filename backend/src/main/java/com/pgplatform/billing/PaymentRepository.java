package com.pgplatform.billing;

import org.springframework.data.jpa.repository.JpaRepository;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public interface PaymentRepository extends JpaRepository<Payment, UUID> {
    List<Payment> findAllByFeeIdAndDeletedAtIsNullOrderByPaidOnDesc(UUID feeId);

    default BigDecimal sumPaidForFee(UUID feeId) {
        return findAllByFeeIdAndDeletedAtIsNullOrderByPaidOnDesc(feeId).stream()
                .map(Payment::getAmountPaid)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }
}
