package com.pgplatform.owner;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface OwnerSmsMessageRepository extends JpaRepository<OwnerSmsMessage, UUID> {
    Optional<OwnerSmsMessage> findByPgIdAndEventKeyAndDeletedAtIsNull(UUID pgId, String eventKey);
}
