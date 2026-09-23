package com.pgplatform.owner;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface PgDirectPaymentSettingsRepository extends JpaRepository<PgDirectPaymentSettings, UUID> {
    Optional<PgDirectPaymentSettings> findByPgIdAndDeletedAtIsNull(UUID pgId);

    boolean existsByPgIdAndEnabledTrueAndVerifiedTrueAndDeletedAtIsNull(UUID pgId);
}
