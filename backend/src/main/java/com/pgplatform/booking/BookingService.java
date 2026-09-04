package com.pgplatform.booking;

import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.booking.dto.BookingCreateRequest;
import com.pgplatform.booking.dto.BookingResponse;
import com.pgplatform.common.ConflictException;
import com.pgplatform.common.ForbiddenException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.discovery.BedAvailabilityBroadcaster;
import com.pgplatform.notification.NotificationService;
import com.pgplatform.owner.Bed;
import com.pgplatform.owner.BedRepository;
import com.pgplatform.owner.BedStatus;
import com.pgplatform.owner.Pg;
import com.pgplatform.owner.PgStatus;
import com.pgplatform.student.Student;
import com.pgplatform.student.StudentRepository;
import com.pgplatform.student.StudentStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Phase 11 -- the critical-path business rule of the whole project: two
 * students must never end up with a CONFIRMED booking on the same bed, even
 * under concurrent requests. See BedAvailabilityBookingConcurrencyTest for
 * the explicit two-simultaneous-requests acceptance test, and
 * docs/decisions.md ADR-0017 for why this uses a pessimistic row lock
 * rather than optimistic locking or a bulk compare-and-swap update.
 */
@Service
public class BookingService {

    private final BookingRepository bookingRepository;
    private final BedRepository bedRepository;
    private final StudentRepository studentRepository;
    private final UserRepository userRepository;
    private final BedAvailabilityBroadcaster broadcaster;
    private final NotificationService notificationService;

    public BookingService(BookingRepository bookingRepository, BedRepository bedRepository,
                           StudentRepository studentRepository, UserRepository userRepository,
                           BedAvailabilityBroadcaster broadcaster, NotificationService notificationService) {
        this.bookingRepository = bookingRepository;
        this.bedRepository = bedRepository;
        this.studentRepository = studentRepository;
        this.userRepository = userRepository;
        this.broadcaster = broadcaster;
        this.notificationService = notificationService;
    }

    @Transactional
    public BookingResponse book(UUID userId, BookingCreateRequest request) {
        if (bookingRepository.countActiveConfirmedForUser(userId) > 0) {
            throw new ConflictException("You already have an active booking. Cancel it before booking another bed.");
        }

        // Pessimistic row lock: any other transaction trying to lock this
        // same bed (another student booking it, or an owner changing its
        // status) blocks here until this transaction commits or rolls
        // back. That serialization is what makes the availability check
        // immediately below safe from a race.
        Bed bed = bedRepository.findByIdForUpdate(request.bedId())
                .orElseThrow(() -> new NotFoundException("Bed not found"));

        Pg pg = bed.getRoom().getFloor().getPg();
        if (pg.getStatus() != PgStatus.ACTIVE) {
            throw new ConflictException("This PG is not currently accepting bookings");
        }
        if (bed.getStatus() != BedStatus.AVAILABLE) {
            throw new ConflictException("That bed is no longer available");
        }

        bed.setStatus(BedStatus.OCCUPIED);
        bedRepository.save(bed);

        Student student = findOrCreateStudentForUser(userId, pg, bed, request.moveInDate());

        Booking booking = new Booking();
        booking.setStudent(student);
        booking.setBed(bed);
        booking.setPg(pg);
        booking.setStatus(BookingStatus.CONFIRMED);
        booking.setMoveInDate(request.moveInDate());
        booking.setConfirmedAt(Instant.now());
        booking = bookingRepository.save(booking);

        broadcaster.notifyChanged(pg.getId());
        notificationService.notifyUser(userId, "Booking confirmed",
                "You're booked into " + bed.getLabel() + " at " + pg.getName() + ". Move-in date: " + request.moveInDate() + ".");
        notificationService.notifyUser(pg.getOwner().getId(), "New booking",
                student.getFullName() + " booked " + bed.getLabel() + " at " + pg.getName() + ".");
        return BookingResponse.from(booking);
    }

    @Transactional(readOnly = true)
    public List<BookingResponse> listForUser(UUID userId) {
        return bookingRepository.findAllForUser(userId).stream().map(BookingResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public BookingResponse get(UUID bookingId, UUID userId) {
        Booking booking = requireOwnedByUser(bookingId, userId);
        return BookingResponse.from(booking);
    }

    @Transactional
    public BookingResponse cancel(UUID bookingId, UUID userId, String reason) {
        Booking booking = requireOwnedByUser(bookingId, userId);
        if (booking.getStatus() == BookingStatus.CANCELLED) {
            throw new ConflictException("This booking is already cancelled");
        }

        // Same lock discipline as book(): touch the bed under a row lock
        // before freeing it, so a cancel racing a fresh book() attempt on
        // the same bed can't interleave incorrectly.
        Bed bed = bedRepository.findByIdForUpdate(booking.getBed().getId())
                .orElseThrow(() -> new NotFoundException("Bed not found"));
        bed.setStatus(BedStatus.AVAILABLE);
        bedRepository.save(bed);

        Student student = booking.getStudent();
        if (student.getBed() != null && student.getBed().getId().equals(bed.getId())) {
            student.setBed(null);
            student.setStatus(StudentStatus.MOVED_OUT);
            studentRepository.save(student);
        }

        booking.setStatus(BookingStatus.CANCELLED);
        booking.setCancelledAt(Instant.now());
        booking.setCancellationReason(reason);
        booking = bookingRepository.save(booking);

        broadcaster.notifyChanged(booking.getPg().getId());
        notificationService.notifyUser(booking.getPg().getOwner().getId(), "Booking cancelled",
                student.getFullName() + " cancelled their booking for " + bed.getLabel() + " at " + booking.getPg().getName() + ".");
        return BookingResponse.from(booking);
    }

    private Booking requireOwnedByUser(UUID bookingId, UUID userId) {
        Booking booking = bookingRepository.findByIdAndDeletedAtIsNull(bookingId)
                .orElseThrow(() -> new NotFoundException("Booking not found"));
        if (booking.getStudent().getUser() == null || !booking.getStudent().getUser().getId().equals(userId)) {
            throw new ForbiddenException("This booking does not belong to you");
        }
        return booking;
    }

    /**
     * A logged-in Student user gets at most one linked Student record
     * (students.user_id is unique -- see V9 migration). First booking ever
     * creates it, pre-filled from the User's own name/phone; a later
     * booking (after a prior one was cancelled) reuses the same record.
     */
    private Student findOrCreateStudentForUser(UUID userId, Pg pg, Bed bed, java.time.LocalDate moveInDate) {
        return studentRepository.findByUserIdAndDeletedAtIsNull(userId)
                .map(existing -> {
                    existing.setPg(pg);
                    existing.setBed(bed);
                    existing.setStatus(StudentStatus.ACTIVE);
                    existing.setMoveOutDate(null);
                    return studentRepository.save(existing);
                })
                .orElseGet(() -> {
                    User user = userRepository.findByIdAndDeletedAtIsNull(userId)
                            .orElseThrow(() -> new NotFoundException("Student account not found"));
                    Student student = new Student();
                    student.setUser(user);
                    student.setPg(pg);
                    student.setBed(bed);
                    student.setFullName(user.getFullName());
                    student.setPhone(user.getPhone() != null ? user.getPhone() : "");
                    student.setDateOfJoining(moveInDate);
                    student.setStatus(StudentStatus.ACTIVE);
                    return studentRepository.save(student);
                });
    }
}
