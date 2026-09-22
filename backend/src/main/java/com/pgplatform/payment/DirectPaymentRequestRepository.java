package com.pgplatform.payment;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface DirectPaymentRequestRepository extends JpaRepository<DirectPaymentRequest, UUID> {
    Optional<DirectPaymentRequest> findByIdAndDeletedAtIsNull(UUID id);
    Optional<DirectPaymentRequest> findByIdempotencyKeyAndDeletedAtIsNull(String key);
    Optional<DirectPaymentRequest> findByDecisionIdempotencyKeyAndDeletedAtIsNull(String key);
    Optional<DirectPaymentRequest> findFirstByBookingIdAndDeletedAtIsNullOrderByCreatedAtDesc(UUID bookingId);
    boolean existsByPgIdAndTransactionReferenceIgnoreCaseAndDeletedAtIsNull(UUID pgId, String reference);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select r from DirectPaymentRequest r where r.id = :id and r.deletedAt is null")
    Optional<DirectPaymentRequest> findByIdForUpdate(@Param("id") UUID id);

    List<DirectPaymentRequest> findAllByPgIdAndStatusAndDeletedAtIsNullOrderBySubmittedAtDesc(
            UUID pgId, DirectPaymentStatus status);
    List<DirectPaymentRequest> findAllByPgIdAndDeletedAtIsNullOrderBySubmittedAtDesc(UUID pgId);

    @Query("select r from DirectPaymentRequest r where r.pg.owner.id = :ownerId and r.deletedAt is null " +
            "and (:status is null or r.status = :status) order by r.submittedAt desc")
    List<DirectPaymentRequest> findForOwner(@Param("ownerId") UUID ownerId,
                                           @Param("status") DirectPaymentStatus status);

    List<DirectPaymentRequest> findAllByStatusAndReviewDueAtBeforeAndDeletedAtIsNull(
            DirectPaymentStatus status, Instant before);

    @Query("select count(r) from DirectPaymentRequest r where r.pg.owner.id = :ownerId " +
            "and r.status in ('PENDING', 'REVIEW_OVERDUE') and r.deletedAt is null")
    long countPendingForOwner(@Param("ownerId") UUID ownerId);

    @Query("select count(r) from DirectPaymentRequest r where r.pg.id = :pgId " +
            "and r.status in ('PENDING', 'REVIEW_OVERDUE') and r.deletedAt is null")
    long countPendingForPg(@Param("pgId") UUID pgId);

    @Query("select coalesce(sum(r.confirmedAmount), 0) from DirectPaymentRequest r " +
            "where r.pg.owner.id = :ownerId and r.status = 'APPROVED' and r.reviewedAt >= :from and r.reviewedAt < :to " +
            "and r.deletedAt is null")
    BigDecimal sumApprovedForOwner(@Param("ownerId") UUID ownerId,
                                   @Param("from") Instant from, @Param("to") Instant to);

    @Query("select coalesce(sum(r.confirmedAmount), 0) from DirectPaymentRequest r " +
            "where r.pg.id = :pgId and r.status = 'APPROVED' and r.reviewedAt >= :from and r.reviewedAt < :to " +
            "and r.deletedAt is null")
    BigDecimal sumApprovedForPg(@Param("pgId") UUID pgId,
                                @Param("from") Instant from, @Param("to") Instant to);
}
