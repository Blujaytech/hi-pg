package com.pgplatform.notification;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface DeviceTokenRepository extends JpaRepository<DeviceToken, UUID> {
    List<DeviceToken> findAllByUserIdAndDeletedAtIsNull(UUID userId);
    Optional<DeviceToken> findByTokenAndDeletedAtIsNull(String token);
}
