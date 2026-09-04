package com.pgplatform.owner;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface PgRepository extends JpaRepository<Pg, UUID> {
    Optional<Pg> findByIdAndDeletedAtIsNull(UUID id);
    List<Pg> findAllByOwnerIdAndDeletedAtIsNullOrderByCreatedAtDesc(UUID ownerId);
    long countByOwnerIdAndDeletedAtIsNull(UUID ownerId);

    /**
     * Public search (technical plan §6 Phase 9) -- only ever returns
     * {@code ACTIVE} PGs. Rent filters are pushed down as EXISTS subqueries
     * against Room so pagination stays correct at the database level
     * (no post-fetch filtering in Java).
     */
    @Query(value = "select p from Pg p where p.deletedAt is null and p.status = 'ACTIVE' " +
            "and (:city is null or lower(p.city) = lower(:city)) " +
            "and (:genderPreference is null or p.genderPreference = :genderPreference) " +
            "and (:minRent is null or exists (select 1 from Room r where r.floor.pg = p and r.deletedAt is null and r.rentPerBed >= :minRent)) " +
            "and (:maxRent is null or exists (select 1 from Room r where r.floor.pg = p and r.deletedAt is null and r.rentPerBed <= :maxRent))",
           countQuery = "select count(p) from Pg p where p.deletedAt is null and p.status = 'ACTIVE' " +
            "and (:city is null or lower(p.city) = lower(:city)) " +
            "and (:genderPreference is null or p.genderPreference = :genderPreference) " +
            "and (:minRent is null or exists (select 1 from Room r where r.floor.pg = p and r.deletedAt is null and r.rentPerBed >= :minRent)) " +
            "and (:maxRent is null or exists (select 1 from Room r where r.floor.pg = p and r.deletedAt is null and r.rentPerBed <= :maxRent))")
    Page<Pg> search(@Param("city") String city, @Param("genderPreference") GenderPreference genderPreference,
                     @Param("minRent") java.math.BigDecimal minRent, @Param("maxRent") java.math.BigDecimal maxRent,
                     Pageable pageable);

    Optional<Pg> findByIdAndDeletedAtIsNullAndStatus(UUID id, PgStatus status);
}
