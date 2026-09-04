package com.pgplatform.student;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.AuthProviderType;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.common.ConflictException;
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
import com.pgplatform.student.dto.AssignBedRequest;
import com.pgplatform.student.dto.StudentCreateRequest;
import com.pgplatform.student.dto.StudentResponse;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class StudentBedAssignmentTest extends AbstractIntegrationTest {

    @Autowired
    private UserRepository userRepository;
    @Autowired
    private PgService pgService;
    @Autowired
    private FloorService floorService;
    @Autowired
    private RoomService roomService;
    @Autowired
    private StudentService studentService;
    @Autowired
    private BedRepository bedRepository;

    private UUID ownerId;
    private UUID pgId;
    private RoomResponse room;

    private void setUp() {
        User owner = new User();
        owner.setEmail("owner-" + UUID.randomUUID() + "@example.com");
        owner.setFullName("Test Owner");
        owner.setRole(Role.OWNER);
        owner.setProvider(AuthProviderType.LOCAL);
        ownerId = userRepository.save(owner).getId();

        pgId = pgService.create(ownerId, new PgCreateRequest("Sunrise PG", "12 MG Road", "Bengaluru",
                null, null, null, null, null, GenderPreference.CO_ED)).id();
        UUID floorId = floorService.create(pgId, ownerId, new FloorCreateRequest("Ground Floor", 0)).id();
        room = roomService.create(floorId, ownerId, new RoomCreateRequest("G-01", 2, new BigDecimal("6000.00"), RoomType.NON_AC));
    }

    @Test
    void assigningAStudentToABedMarksItOccupied() {
        setUp();
        UUID bedId = room.beds().get(0).id();

        StudentResponse student = studentService.create(pgId, ownerId, new StudentCreateRequest(
                "Asha Rao", "9999999999", null, null, null, null, null, LocalDate.now(), bedId.toString()));

        assertThat(student.bedId()).isEqualTo(bedId);
        assertThat(bedRepository.findByIdAndDeletedAtIsNull(bedId).orElseThrow().getStatus()).isEqualTo(BedStatus.OCCUPIED);
    }

    @Test
    void cannotAssignTwoStudentsToTheSameBed() {
        setUp();
        UUID bedId = room.beds().get(0).id();

        studentService.create(pgId, ownerId, new StudentCreateRequest(
                "Asha Rao", "9999999999", null, null, null, null, null, LocalDate.now(), bedId.toString()));

        StudentResponse second = studentService.create(pgId, ownerId, new StudentCreateRequest(
                "Priya Singh", "8888888888", null, null, null, null, null, LocalDate.now(), null));

        assertThatThrownBy(() -> studentService.assignBed(UUID.fromString(second.id().toString()), ownerId, new AssignBedRequest(bedId.toString())))
                .isInstanceOf(ConflictException.class);
    }

    @Test
    void movingOutFreesTheBed() {
        setUp();
        UUID bedId = room.beds().get(0).id();

        StudentResponse student = studentService.create(pgId, ownerId, new StudentCreateRequest(
                "Asha Rao", "9999999999", null, null, null, null, null, LocalDate.now(), bedId.toString()));

        StudentResponse movedOut = studentService.moveOut(student.id(), ownerId);

        assertThat(movedOut.status()).isEqualTo(StudentStatus.MOVED_OUT);
        assertThat(movedOut.bedId()).isNull();
        assertThat(bedRepository.findByIdAndDeletedAtIsNull(bedId).orElseThrow().getStatus()).isEqualTo(BedStatus.AVAILABLE);
    }
}
