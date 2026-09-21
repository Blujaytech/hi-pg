package com.pgplatform.billing;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.UUID;

public interface FeeNotificationDeliveryRepository extends JpaRepository<FeeNotificationDelivery, UUID> {
    boolean existsByFeeIdAndNotificationTypeAndEffectiveDueDateAndDeletedAtIsNull(
            UUID feeId, FeeNotificationType notificationType, LocalDate effectiveDueDate);
}
