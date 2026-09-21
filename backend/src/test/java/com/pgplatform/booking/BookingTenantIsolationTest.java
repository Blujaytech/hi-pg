package com.pgplatform.booking;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.AuthProviderType;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.booking.dto.BookingCreateRequest;
import com.pgplatform.booking.dto.BookingResponse;
import com.pgplatform.booking.dto.MoveOutNoticeRequest;
import com.pgplatform.common.ForbiddenException;
import com.pgplatform.owner.BedRepository;
import com.pgplatform.owner.BedStatus;
import com.pgplatform.owner.FloorService;
import com.pgplatform.owner.GenderPreference;
import com.pgplatform.owner.PgService;
import com.pgplatform.owner.RoomService;
import com.pgplatform.owner.RoomType;
import com.pgplatform.owner.dto.FloorCreateRequest;
import com.pgplatform.owner.dto.PgCreateRequest;
import com.pgplatform.owner.dto.RoomCreateRequest;
import com.pgplatform.student.Student;
import com.pgplatform.student.StudentRepository;
import com.pgplatform.student.StudentService;
import com.pgplatform.student.StudentStatus;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * A booking hold is unpaid and expires in ten minutes, so creating one must not move the
 * student's record between PGs. It used to: the hold reassigned {@code student.pg}, and
 * because every ownership check resolves through {@code student.getPg().getOwner()}, the
 * second PG's owner immediately gained access to that student's fees and documents while
 * the owner they were actually living with lost it -- for free, without paying.
 */
class BookingTenantIsolationTest extends AbstractIntegrationTest {

    @Autowired
    private UserRepository userRepository;
    @Autowired
    private PgService pgService;
    @Autowired
    private FloorService floorService;
    @Autowired
    private RoomService roomService;
    @Autowired
    private BookingService bookingService;
    @Autowired
    private StudentService studentService;
    @Autowired
    private StudentRepository studentRepository;
    @Autowired
    private BedRepository bedRepository;

    private record Landlord(UUID ownerId, UUID pgId) {
    }

    private Landlord createLandlord(String pgName) {
        User owner = new User();
        owner.setEmail("owner-" + UUID.randomUUID() + "@example.com");
        owner.setFullName(pgName + " Owner");
        owner.setRole(Role.OWNER);
        owner.setProvider(AuthProviderType.LOCAL);
        UUID ownerId = userRepository.save(owner).getId();
        UUID pgId = pgService.create(ownerId, new PgCreateRequest(pgName, "1 Test St", "Pune",
                null, null, null, null, null, GenderPreference.CO_ED)).id();
        return new Landlord(ownerId, pgId);
    }

    private UUID createBed(Landlord landlord, String roomNumber) {
        UUID floorId = floorService.create(landlord.pgId(), landlord.ownerId(),
                new FloorCreateRequest("Floor " + roomNumber, 1)).id();
        return roomService.create(floorId, landlord.ownerId(), new RoomCreateRequest(roomNumber, 1,
                new BigDecimal("6500.00"), RoomType.NON_AC)).beds().get(0).id();
    }

    private UUID createStudentUser(String phone) {
        User user = new User();
        user.setPhone(phone);
        user.setFullName("Student " + phone);
        user.setRole(Role.STUDENT);
        user.setProvider(AuthProviderType.LOCAL);
        user.setPhoneVerified(true);
        return userRepository.save(user).getId();
    }

    @Test
    void anUnpaidHoldElsewhereDoesNotHandTheStudentToAnotherOwner() {
        Landlord current = createLandlord("Current PG");
        Landlord rival = createLandlord("Rival PG");
        UUID currentBed = createBed(current, "101");
        UUID rivalBed = createBed(rival, "201");
        UUID userId = createStudentUser("9811111111");

        // The student is living at "Current PG" and has given notice, which sets a
        // check-out date and so leaves room for a non-overlapping future booking.
        BookingResponse stay = bookingService.book(userId, new BookingCreateRequest(currentBed, LocalDate.now()));
        bookingService.confirmAfterCapturedPayment(stay.id());
        bookingService.submitMoveOutNotice(stay.id(), userId,
                new MoveOutNoticeRequest(LocalDate.now().plusDays(40)));

        Student student = studentRepository.findByUserIdAndDeletedAtIsNull(userId).orElseThrow();
        assertThat(student.getPg().getId()).isEqualTo(current.pgId());

        // Merely holding a bed at the rival PG -- no payment made, hold expires in 10 minutes.
        bookingService.book(userId, new BookingCreateRequest(rivalBed, BookingType.MONTHLY,
                LocalDate.now().plusDays(45), null));

        Student afterHold = studentRepository.findByUserIdAndDeletedAtIsNull(userId).orElseThrow();
        assertThat(afterHold.getPg().getId()).isEqualTo(current.pgId());
        assertThat(afterHold.getStatus()).isEqualTo(StudentStatus.ACTIVE);
        assertThat(afterHold.getBed().getId()).isEqualTo(currentBed);

        // The owner they actually live with keeps access; the rival owner never gains it.
        assertThat(studentService.get(afterHold.getId(), current.ownerId()).id()).isEqualTo(afterHold.getId());
        assertThatThrownBy(() -> studentService.get(afterHold.getId(), rival.ownerId()))
                .isInstanceOf(ForbiddenException.class);
    }

    @Test
    void aPaidButFutureDatedBookingLeavesTheStudentOnTheirCurrentRosterUntilArrival() {
        Landlord current = createLandlord("Stay PG");
        Landlord next = createLandlord("Future PG");
        UUID currentBed = createBed(current, "301");
        UUID nextBed = createBed(next, "401");
        UUID userId = createStudentUser("9822222222");

        BookingResponse stay = bookingService.book(userId, new BookingCreateRequest(currentBed, LocalDate.now()));
        bookingService.confirmAfterCapturedPayment(stay.id());
        bookingService.submitMoveOutNotice(stay.id(), userId,
                new MoveOutNoticeRequest(LocalDate.now().plusDays(40)));

        BookingResponse move = bookingService.book(userId, new BookingCreateRequest(nextBed,
                BookingType.MONTHLY, LocalDate.now().plusDays(45), null));
        Booking confirmed = bookingService.confirmAfterCapturedPayment(move.id());

        // Paid for, but they have not moved in yet: nothing about their residency changes.
        assertThat(confirmed.getStatus()).isEqualTo(BookingStatus.CONFIRMED);
        Student student = studentRepository.findByUserIdAndDeletedAtIsNull(userId).orElseThrow();
        assertThat(student.getPg().getId()).isEqualTo(current.pgId());
        assertThat(student.getBed().getId()).isEqualTo(currentBed);
        assertThat(bedRepository.findByIdAndDeletedAtIsNull(nextBed).orElseThrow().getStatus())
                .isEqualTo(BedStatus.AVAILABLE);
    }
}
