package com.pgplatform.owner;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface FloorRepository extends JpaRepository<Floor, UUID> {
    Optional<Floor> findByIdAndDeletedAtIsNull(UUID id);
    List<Floor> findAllByPgIdAndDeletedAtIsNullOrderByFloorNumberAsc(UUID pgId);

    long countByPgIdAndDeletedAtIsNull(UUID pgId);

    @Query("select count(f) from Floor f where f.pg.owner.id = :ownerId and f.deletedAt is null")
    long countByOwnerId(@Param("ownerId") UUID ownerId);
}
