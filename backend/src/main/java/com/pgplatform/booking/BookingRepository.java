package com.pgplatform.booking;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Collection;
import java.util.Optional;
import java.util.UUID;
import java.time.Instant;
import java.time.LocalDate;

public interface BookingRepository extends JpaRepository<Booking, UUID> {
    Optional<Booking> findByIdAndDeletedAtIsNull(UUID id);

    /**
     * Serializes deposit adjustments on the booking row, the same way
     * BedRepository.findByIdForUpdate serializes bed claims -- the deposit ledger is a
     * sum over rows, so without a lock two concurrent refunds each read the same
     * balance and both pass the available-funds check. See DepositService.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select b from Booking b where b.id = :id and b.deletedAt is null")
    Optional<Booking> findByIdForUpdate(@Param("id") UUID id);

    @Query("select b from Booking b where b.student.user.id = :userId and b.deletedAt is null order by b.createdAt desc")
    List<Booking> findAllForUser(@Param("userId") UUID userId);

    Optional<Booking> findFirstByStudentIdAndStatusInAndDeletedAtIsNullOrderByCreatedAtDesc(
            UUID studentId, Collection<BookingStatus> statuses);

    @Query("select count(b) from Booking b where b.student.user.id = :userId and b.status in ('PAYMENT_PENDING', 'DIRECT_PAYMENT_REVIEW', 'CONFIRMED', 'CHECKED_IN') and b.deletedAt is null")
    long countActiveConfirmedForUser(@Param("userId") UUID userId);

    @Query(value = """
            select count(*) from bookings b
            where b.bed_id = :bedId
              and b.status in ('PAYMENT_PENDING', 'DIRECT_PAYMENT_REVIEW', 'CONFIRMED', 'CHECKED_IN')
              and b.deleted_at is null
              and b.move_in_date < :requestedEnd
              and coalesce(b.check_out_date, date '9999-12-31') > :requestedStart
            """, nativeQuery = true)
    long countOverlappingForBed(@Param("bedId") UUID bedId,
                                @Param("requestedStart") LocalDate requestedStart,
                                @Param("requestedEnd") LocalDate requestedEnd);

    @Query(value = """
            select count(*) from bookings b
            join students s on s.id = b.student_id
            where s.user_id = :userId
              and b.status in ('PAYMENT_PENDING', 'DIRECT_PAYMENT_REVIEW', 'CONFIRMED', 'CHECKED_IN')
              and b.deleted_at is null
              and b.move_in_date < :requestedEnd
              and coalesce(b.check_out_date, date '9999-12-31') > :requestedStart
            """, nativeQuery = true)
    long countOverlappingForUser(@Param("userId") UUID userId,
                                 @Param("requestedStart") LocalDate requestedStart,
                                 @Param("requestedEnd") LocalDate requestedEnd);

    List<Booking> findAllByStatusAndPaymentExpiresAtBeforeAndDeletedAtIsNull(BookingStatus status, Instant before);

    List<Booking> findAllByStatusInAndCheckOutDateLessThanEqualAndDeletedAtIsNull(
            Collection<BookingStatus> statuses, LocalDate date);

    List<Booking> findAllByStatusAndMoveInDateLessThanEqualAndDeletedAtIsNull(
            BookingStatus status, LocalDate date);

    @Query("select b from Booking b where b.bed.room.id = :roomId and b.deletedAt is null " +
           "and b.status in ('PAYMENT_PENDING', 'DIRECT_PAYMENT_REVIEW', 'CONFIRMED', 'CHECKED_IN', 'COMPLETED') " +
           "and b.moveInDate < :to and (b.checkOutDate is null or b.checkOutDate > :from) " +
           "order by b.bed.label, b.moveInDate")
    List<Booking> findCalendarForRoom(@Param("roomId") UUID roomId,
                                      @Param("from") LocalDate from,
                                      @Param("to") LocalDate to);
}
