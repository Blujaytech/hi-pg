package com.pgplatform.autopay;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface AutoPayMandateRepository extends JpaRepository<AutoPayMandate, UUID> {
    Optional<AutoPayMandate> findByStudentIdAndDeletedAtIsNull(UUID studentId);
    Optional<AutoPayMandate> findByRazorpaySubscriptionIdAndDeletedAtIsNull(String subscriptionId);
}
