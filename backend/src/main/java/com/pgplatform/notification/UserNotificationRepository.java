package com.pgplatform.notification;

import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface UserNotificationRepository extends JpaRepository<UserNotification, UUID> {
    List<UserNotification> findAllByUserIdAndDeletedAtIsNullOrderByCreatedAtDesc(UUID userId, Pageable pageable);
    Optional<UserNotification> findByIdAndUserIdAndDeletedAtIsNull(UUID id, UUID userId);
    List<UserNotification> findAllByUserIdAndReadAtIsNullAndDeletedAtIsNull(UUID userId);
    long countByUserIdAndReadAtIsNullAndDeletedAtIsNull(UUID userId);
    long countByUserIdAndCategoryAndCreatedAtGreaterThanEqualAndDeletedAtIsNull(
            UUID userId, NotificationCategory category, Instant createdAt);
}
