package com.pgplatform.owner;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PgOwnerContactRepository extends JpaRepository<PgOwnerContact, UUID> {
    Optional<PgOwnerContact> findByPgIdAndDeletedAtIsNull(UUID pgId);
    List<PgOwnerContact> findAllByNormalizedMobileAndDeletedAtIsNullOrderByCreatedAtDesc(String mobile);
    boolean existsByNormalizedMobileAndDeletedAtIsNull(String mobile);
}
