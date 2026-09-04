package com.pgplatform.owner;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.AuthProviderType;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.owner.dto.DashboardSummaryResponse;
import com.pgplatform.owner.dto.FloorCreateRequest;
import com.pgplatform.owner.dto.PgCreateRequest;
import com.pgplatform.owner.dto.RoomCreateRequest;
import com.pgplatform.student.StudentService;
import com.pgplatform.student.dto.StudentCreateRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class DashboardIntegrationTest extends AbstractIntegrationTest {

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
    private DashboardService dashboardService;

    @Test
    void summaryReflectsBedsAndActiveStudents() {
        User owner = new User();
        owner.setEmail("owner-" + UUID.randomUUID() + "@example.com");
        owner.setFullName("Test Owner");
        owner.setRole(Role.OWNER);
        owner.setProvider(AuthProviderType.LOCAL);
        UUID ownerId = userRepository.save(owner).getId();

        UUID pgId = pgService.create(ownerId, new PgCreateRequest("Sunrise PG", "12 MG Road", "Bengaluru",
                null, null, null, null, null, GenderPreference.CO_ED)).id();
        UUID floorId = floorService.create(pgId, ownerId, new FloorCreateRequest("Ground Floor", 0)).id();
        var room = roomService.create(floorId, ownerId, new RoomCreateRequest("G-01", 3, new BigDecimal("6000.00"), RoomType.NON_AC));

        studentService.create(pgId, ownerId, new StudentCreateRequest(
                "Asha Rao", "9999999999", null, null, null, null, null, LocalDate.now(), room.beds().get(0).id().toString()));

        DashboardSummaryResponse ownerSummary = dashboardService.forOwner(ownerId);
        assertThat(ownerSummary.totalPgs()).isEqualTo(1);
        assertThat(ownerSummary.totalFloors()).isEqualTo(1);
        assertThat(ownerSummary.totalRooms()).isEqualTo(1);
        assertThat(ownerSummary.totalBeds()).isEqualTo(3);
        assertThat(ownerSummary.occupiedBeds()).isEqualTo(1);
        assertThat(ownerSummary.availableBeds()).isEqualTo(2);
        assertThat(ownerSummary.totalActiveStudents()).isEqualTo(1);
        assertThat(ownerSummary.occupancyPercentage()).isEqualTo(33.33);

        DashboardSummaryResponse pgSummary = dashboardService.forPg(pgId, ownerId);
        assertThat(pgSummary.totalBeds()).isEqualTo(3);
        assertThat(pgSummary.occupiedBeds()).isEqualTo(1);
    }
}
