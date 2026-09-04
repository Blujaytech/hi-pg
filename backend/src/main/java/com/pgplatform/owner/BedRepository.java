package com.pgplatform.owner;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import jakarta.persistence.LockModeType;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface BedRepository extends JpaRepository<Bed, UUID> {
    Optional<Bed> findByIdAndDeletedAtIsNull(UUID id);
    List<Bed> findAllByRoomIdAndDeletedAtIsNullOrderByLabelAsc(UUID roomId);
    List<Bed> findAllByRoomIdAndStatusAndDeletedAtIsNull(UUID roomId, BedStatus status);
    long countByRoomIdAndDeletedAtIsNull(UUID roomId);
    long countByRoomIdAndStatusAndDeletedAtIsNull(UUID roomId, BedStatus status);

    /**
     * Phase 11's concurrency-safety mechanism: takes a Postgres row lock
     * (SELECT ... FOR UPDATE) on this bed, so a second concurrent caller
     * trying to lock the same bed blocks until the first transaction
     * commits or rolls back -- see BookingService.book and
     * docs/decisions.md ADR-0017. Deliberately a normal entity fetch (not a
     * bulk @Modifying update) so the usual JPA auditing (updatedAt/By)
     * still fires when the bed is saved afterward.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select b from Bed b where b.id = :id and b.deletedAt is null")
    Optional<Bed> findByIdForUpdate(@Param("id") UUID id);

    @Query("select count(b) from Bed b where b.room.floor.pg.id = :pgId and b.deletedAt is null")
    long countByPgId(@Param("pgId") UUID pgId);

    @Query("select count(b) from Bed b where b.room.floor.pg.id = :pgId and b.status = :status and b.deletedAt is null")
    long countByPgIdAndStatus(@Param("pgId") UUID pgId, @Param("status") BedStatus status);

    @Query("select count(b) from Bed b where b.room.floor.pg.owner.id = :ownerId and b.deletedAt is null")
    long countByOwnerId(@Param("ownerId") UUID ownerId);

    @Query("select count(b) from Bed b where b.room.floor.pg.owner.id = :ownerId and b.status = :status and b.deletedAt is null")
    long countByOwnerIdAndStatus(@Param("ownerId") UUID ownerId, @Param("status") BedStatus status);
}
