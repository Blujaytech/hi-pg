package com.pgplatform.owner;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PgPhotoRepository extends JpaRepository<PgPhoto, UUID> {
    List<PgPhoto> findAllByPgIdAndDeletedAtIsNullOrderByDisplayOrderAscCreatedAtAsc(UUID pgId);
    Optional<PgPhoto> findByIdAndPgIdAndDeletedAtIsNull(UUID id, UUID pgId);
    long countByPgIdAndDeletedAtIsNull(UUID pgId);
}
