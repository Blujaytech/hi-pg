package com.pgplatform.owner;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface PgInterestRequestRepository extends JpaRepository<PgInterestRequest, UUID> {
    Optional<PgInterestRequest> findByPgIdAndCustomerIdAndDeletedAtIsNull(UUID pgId, UUID customerId);
    long countByPgIdAndDeletedAtIsNull(UUID pgId);
}
