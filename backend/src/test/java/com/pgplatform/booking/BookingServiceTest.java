package com.pgplatform.booking;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.AuthProviderType;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.booking.dto.BookingCreateRequest;
import com.pgplatform.booking.dto.BookingResponse;
import com.pgplatform.common.ConflictException;
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
import com.pgplatform.owner.dto.RoomResponse;
import com.pgplatform.student.StudentRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class BookingServiceTest extends AbstractIntegrationTest {

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
    private BedRepository bedRepository;
    @Autowired
    private StudentRepository studentRepository;

    private UUID ownerId;
    private UUID pgId;

    private UUID createBed(String roomNumber) {
        UUID floorId = floorService.create(pgId, ownerId, new FloorCreateRequest("Floor " + roomNumber, 1)).id();
        RoomResponse room = roomService.create(floorId, ownerId, new RoomCreateRequest(roomNumber, 1,
                new BigDecimal("6500.00"), RoomType.NON_AC));
        return room.beds().get(0).id();
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

    private void setUpOwnerAndPg() {
        User owner = new User();
        owner.setEmail("owner-" + UUID.randomUUID() + "@example.com");
        owner.setFullName("Booking Test Owner");
        owner.setRole(Role.OWNER);
        owner.setProvider(AuthProviderType.LOCAL);
        ownerId = userRepository.save(owner).getId();

        pgId = pgService.create(ownerId, new PgCreateRequest("Booking PG", "2 Test St", "Mumbai",
                null, null, null, null, null, GenderPreference.CO_ED)).id();
    }

    @Test
    void bookingCreatesALinkedStudentRecordAndOccupiesTheBed() {
        setUpOwnerAndPg();
        UUID bedId = createBed("201");
        UUID userId = createStudentUser("9111111111");

        BookingResponse booking = bookingService.book(userId, new BookingCreateRequest(bedId, LocalDate.now().plusDays(2)));

        assertThat(booking.status()).isEqualTo(BookingStatus.CONFIRMED);
        assertThat(bedRepository.findByIdAndDeletedAtIsNull(bedId).orElseThrow().getStatus()).isEqualTo(BedStatus.OCCUPIED);

        var student = studentRepository.findByUserIdAndDeletedAtIsNull(userId).orElseThrow();
        assertThat(student.getBed().getId()).isEqualTo(bedId);
        assertThat(student.getFullName()).isEqualTo("Student 9111111111");
    }

    @Test
    void aSecondBookingAttemptByTheSameUserIsRejectedWhileTheFirstIsActive() {
        setUpOwnerAndPg();
        UUID bedId1 = createBed("301");
        UUID bedId2 = createBed("302");
        UUID userId = createStudentUser("9222222222");

        bookingService.book(userId, new BookingCreateRequest(bedId1, LocalDate.now().plusDays(1)));

        assertThatThrownBy(() -> bookingService.book(userId, new BookingCreateRequest(bedId2, LocalDate.now().plusDays(1))))
                .isInstanceOf(ConflictException.class);
    }

    @Test
    void bookingAnAlreadyOccupiedBedIsRejected() {
        setUpOwnerAndPg();
        UUID bedId = createBed("401");
        UUID userA = createStudentUser("9333333333");
        UUID userB = createStudentUser("9333333334");

        bookingService.book(userA, new BookingCreateRequest(bedId, LocalDate.now().plusDays(1)));

        assertThatThrownBy(() -> bookingService.book(userB, new BookingCreateRequest(bedId, LocalDate.now().plusDays(1))))
                .isInstanceOf(ConflictException.class);
    }

    @Test
    void cancellingFreesTheBedAndAnotherUserCanThenBookIt() {
        setUpOwnerAndPg();
        UUID bedId = createBed("501");
        UUID userA = createStudentUser("9444444444");
        UUID userB = createStudentUser("9444444445");

        BookingResponse booking = bookingService.book(userA, new BookingCreateRequest(bedId, LocalDate.now().plusDays(1)));
        bookingService.cancel(booking.id(), userA, "Changed my mind");

        assertThat(bedRepository.findByIdAndDeletedAtIsNull(bedId).orElseThrow().getStatus()).isEqualTo(BedStatus.AVAILABLE);

        BookingResponse secondBooking = bookingService.book(userB, new BookingCreateRequest(bedId, LocalDate.now().plusDays(1)));
        assertThat(secondBooking.status()).isEqualTo(BookingStatus.CONFIRMED);
    }

    @Test
    void aUserCannotCancelSomeoneElsesBooking() {
        setUpOwnerAndPg();
        UUID bedId = createBed("601");
        UUID userA = createStudentUser("9555555555");
        UUID userB = createStudentUser("9555555556");

        BookingResponse booking = bookingService.book(userA, new BookingCreateRequest(bedId, LocalDate.now().plusDays(1)));

        assertThatThrownBy(() -> bookingService.cancel(booking.id(), userB, "not mine"))
                .isInstanceOf(ForbiddenException.class);
    }
}
