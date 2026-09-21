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

    /** Everything a free-text search word may match, lower-cased. */
    String SEARCH_TEXT = "lower(concat(coalesce(p.name, ''), ' ', coalesce(p.address, ''), ' ', " +
            "coalesce(p.city, ''), ' ', coalesce(p.state, ''), ' ', coalesce(p.pincode, '')))";

    String SEARCH_WHERE = "where p.deletedAt is null and p.status = 'ACTIVE' " +
            "and (:word1 is null or " + SEARCH_TEXT + " like cast(:word1 as string) escape '\\') " +
            "and (:word2 is null or " + SEARCH_TEXT + " like cast(:word2 as string) escape '\\') " +
            "and (:word3 is null or " + SEARCH_TEXT + " like cast(:word3 as string) escape '\\') " +
            "and (:city is null or lower(p.city) = lower(cast(:city as string))) " +
            "and (:genderPreference is null or p.genderPreference = :genderPreference) " +
            "and (:minRent is null or exists (select 1 from Room r where r.floor.pg = p and r.deletedAt is null and r.rentPerBed >= :minRent)) " +
            "and (:maxRent is null or exists (select 1 from Room r where r.floor.pg = p and r.deletedAt is null and r.rentPerBed <= :maxRent))";

    /**
     * Public search (technical plan §6 Phase 9) -- only ever returns
     * {@code ACTIVE} PGs. {@code word1..3} are lower-cased, wildcard-escaped
     * {@code %word%} LIKE patterns (see PgSearchService); each must match
     * somewhere in {@link #SEARCH_TEXT}. Rent filters are pushed down as
     * EXISTS subqueries against Room so pagination stays correct at the
     * database level (no post-fetch filtering in Java).
     */
    @Query(value = "select p from Pg p " + SEARCH_WHERE,
           countQuery = "select count(p) from Pg p " + SEARCH_WHERE)
    Page<Pg> search(@Param("word1") String word1, @Param("word2") String word2, @Param("word3") String word3,
                     @Param("city") String city, @Param("genderPreference") GenderPreference genderPreference,
                     @Param("minRent") java.math.BigDecimal minRent, @Param("maxRent") java.math.BigDecimal maxRent,
                     Pageable pageable);

    Optional<Pg> findByIdAndDeletedAtIsNullAndStatus(UUID id, PgStatus status);
    List<Pg> findAllByPaymentOnboardingStatusAndDeletedAtIsNullOrderByCreatedAtAsc(
            PaymentOnboardingStatus paymentOnboardingStatus);
}
