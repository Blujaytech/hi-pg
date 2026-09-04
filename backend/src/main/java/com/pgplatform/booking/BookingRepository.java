package com.pgplatform.booking;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface BookingRepository extends JpaRepository<Booking, UUID> {
    Optional<Booking> findByIdAndDeletedAtIsNull(UUID id);

    @Query("select b from Booking b where b.student.user.id = :userId and b.deletedAt is null order by b.createdAt desc")
    List<Booking> findAllForUser(@Param("userId") UUID userId);

    @Query("select count(b) from Booking b where b.student.user.id = :userId and b.status = 'CONFIRMED' and b.deletedAt is null")
    long countActiveConfirmedForUser(@Param("userId") UUID userId);
}
