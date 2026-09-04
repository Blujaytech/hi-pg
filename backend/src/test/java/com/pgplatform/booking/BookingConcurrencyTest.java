package com.pgplatform.booking;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.AuthProviderType;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.booking.dto.BookingCreateRequest;
import com.pgplatform.booking.dto.BookingResponse;
import com.pgplatform.common.ConflictException;
import com.pgplatform.owner.FloorService;
import com.pgplatform.owner.GenderPreference;
import com.pgplatform.owner.PgService;
import com.pgplatform.owner.RoomService;
import com.pgplatform.owner.RoomType;
import com.pgplatform.owner.dto.FloorCreateRequest;
import com.pgplatform.owner.dto.PgCreateRequest;
import com.pgplatform.owner.dto.RoomCreateRequest;
import com.pgplatform.owner.dto.RoomResponse;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * The explicit acceptance criterion for Phase 11 (technical plan §6):
 * "This phase should include a written concurrency test (two simulated
 * simultaneous booking requests against one bed) as an explicit acceptance
 * criterion, not just code review." This is that test.
 *
 * Two real threads, each with its own transaction (BookingService.book is
 * @Transactional, and this test class carries no test-level @Transactional
 * rollback wrapper -- see AbstractIntegrationTest), race to book the SAME
 * single bed for two DIFFERENT student users, released at the same instant
 * via a CountDownLatch. Exactly one must succeed; the other must fail with
 * ConflictException, never with a corrupted double-booked state.
 */
class BookingConcurrencyTest extends AbstractIntegrationTest {

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
    private BookingRepository bookingRepository;

    @Test
    void exactlyOneOfTwoSimultaneousBookingsOnTheSameBedSucceeds() throws Exception {
        User owner = new User();
        owner.setEmail("owner-" + UUID.randomUUID() + "@example.com");
        owner.setFullName("Concurrency Owner");
        owner.setRole(Role.OWNER);
        owner.setProvider(AuthProviderType.LOCAL);
        UUID ownerId = userRepository.save(owner).getId();

        UUID pgId = pgService.create(ownerId, new PgCreateRequest("Race PG", "1 Test St", "Bengaluru",
                null, null, null, null, null, GenderPreference.CO_ED)).id();
        UUID floorId = floorService.create(pgId, ownerId, new FloorCreateRequest("Floor 1", 1)).id();
        RoomResponse room = roomService.create(floorId, ownerId, new RoomCreateRequest("101", 1,
                new BigDecimal("7000.00"), RoomType.NON_AC));
        UUID bedId = room.beds().get(0).id();

        UUID studentUserA = createStudentUser("Student A", "9000000001");
        UUID studentUserB = createStudentUser("Student B", "9000000002");

        CountDownLatch readyLatch = new CountDownLatch(2);
        CountDownLatch startLatch = new CountDownLatch(1);
        ExecutorService pool = Executors.newFixedThreadPool(2);

        Callable<Object> bookAsA = bookingAttempt(studentUserA, bedId, readyLatch, startLatch);
        Callable<Object> bookAsB = bookingAttempt(studentUserB, bedId, readyLatch, startLatch);

        Future<Object> resultA = pool.submit(bookAsA);
        Future<Object> resultB = pool.submit(bookAsB);

        assertThat(readyLatch.await(5, TimeUnit.SECONDS)).isTrue();
        startLatch.countDown(); // release both threads at (as close to) the same instant as possible

        Object outcomeA = getOutcome(resultA);
        Object outcomeB = getOutcome(resultB);
        pool.shutdown();

        List<Object> outcomes = List.of(outcomeA, outcomeB);
        long successes = outcomes.stream().filter(o -> o instanceof BookingResponse).count();
        long conflicts = outcomes.stream().filter(o -> o instanceof ConflictException).count();

        assertThat(successes).as("exactly one booking must succeed").isEqualTo(1);
        assertThat(conflicts).as("the other must fail with a clean 409, not corrupt state").isEqualTo(1);

        long confirmedBookingsOnThisBed = bookingRepository.findAll().stream()
                .filter(b -> b.getBed().getId().equals(bedId))
                .filter(b -> b.getStatus() == BookingStatus.CONFIRMED)
                .filter(b -> b.getDeletedAt() == null)
                .count();
        assertThat(confirmedBookingsOnThisBed).as("never more than one CONFIRMED booking on the same bed").isEqualTo(1);
    }

    private Callable<Object> bookingAttempt(UUID userId, UUID bedId, CountDownLatch readyLatch, CountDownLatch startLatch) {
        return () -> {
            readyLatch.countDown();
            startLatch.await();
            try {
                return bookingService.book(userId, new BookingCreateRequest(bedId, LocalDate.now().plusDays(1)));
            } catch (ConflictException e) {
                return e;
            }
        };
    }

    private Object getOutcome(Future<Object> future) throws Exception {
        return future.get(10, TimeUnit.SECONDS);
    }

    private UUID createStudentUser(String fullName, String phone) {
        User user = new User();
        user.setPhone(phone);
        user.setFullName(fullName);
        user.setRole(Role.STUDENT);
        user.setProvider(AuthProviderType.LOCAL);
        user.setPhoneVerified(true);
        return userRepository.save(user).getId();
    }
}
