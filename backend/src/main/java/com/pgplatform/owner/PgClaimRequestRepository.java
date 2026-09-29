package com.pgplatform.owner;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PgClaimRequestRepository extends JpaRepository<PgClaimRequest, UUID> {
    Optional<PgClaimRequest> findByPgIdAndStatusAndDeletedAtIsNull(UUID pgId, PgClaimRequestStatus status);
    Optional<PgClaimRequest> findByPgIdAndClaimantIdAndDeletedAtIsNull(UUID pgId, UUID claimantId);
    List<PgClaimRequest> findAllByClaimantIdAndDeletedAtIsNullOrderByCreatedAtDesc(UUID claimantId);
}
