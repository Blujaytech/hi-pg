package com.pgplatform.billing;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface FeeRepository extends JpaRepository<Fee, UUID> {
    Optional<Fee> findByIdAndDeletedAtIsNull(UUID id);

    /**
     * Serializes concurrent checkout creation for one fee. Without it two
     * simultaneous "Pay now" taps can both read "no open order" and create
     * two payable Razorpay orders for the same fee (see V20).
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select f from Fee f where f.id = :id and f.deletedAt is null")
    Optional<Fee> findByIdForUpdate(@Param("id") UUID id);
    List<Fee> findAllByStatusNotAndDeletedAtIsNull(FeeStatus status);
    boolean existsByStudentIdAndPeriodYearAndPeriodMonthAndDeletedAtIsNull(UUID studentId, Integer periodYear, Integer periodMonth);
    List<Fee> findAllByStudentIdAndDeletedAtIsNullOrderByPeriodYearDescPeriodMonthDesc(UUID studentId);
    List<Fee> findAllByPgIdAndDeletedAtIsNullOrderByDueDateDesc(UUID pgId);

    @Query("select coalesce(sum(f.amount), 0) from Fee f " +
           "where f.pg.owner.id = :ownerId and f.status <> 'PAID' and f.deletedAt is null")
    BigDecimal sumPendingDuesByOwnerId(@Param("ownerId") UUID ownerId);

    @Query("select coalesce(sum(p.amountPaid), 0) from Payment p " +
           "where p.fee.pg.owner.id = :ownerId and p.deletedAt is null " +
           "and p.paidOn >= :from and p.paidOn <= :to")
    BigDecimal sumCollectedByOwnerIdBetween(@Param("ownerId") UUID ownerId, @Param("from") java.time.LocalDate from, @Param("to") java.time.LocalDate to);
    @Query("select coalesce(sum(f.amount), 0) from Fee f " +
           "where f.pg.id = :pgId and f.status <> 'PAID' and f.deletedAt is null")
    BigDecimal sumPendingDuesByPgId(@Param("pgId") UUID pgId);

    @Query("select coalesce(sum(p.amountPaid), 0) from Payment p " +
           "where p.fee.pg.id = :pgId and p.deletedAt is null " +
           "and p.paidOn >= :from and p.paidOn <= :to")
    BigDecimal sumCollectedByPgIdBetween(@Param("pgId") UUID pgId, @Param("from") java.time.LocalDate from, @Param("to") java.time.LocalDate to);

    List<Fee> findAllByPgOwnerIdAndStatusNotAndDeletedAtIsNullOrderByDueDateAsc(UUID ownerId, FeeStatus status);
    List<Fee> findAllByPgIdAndStatusNotAndDeletedAtIsNullOrderByDueDateAsc(UUID pgId, FeeStatus status);
}
