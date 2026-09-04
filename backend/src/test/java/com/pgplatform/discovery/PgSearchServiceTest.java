package com.pgplatform.discovery;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.AuthProviderType;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.common.PagedResponse;
import com.pgplatform.discovery.dto.PgDetailsResponse;
import com.pgplatform.discovery.dto.PgSearchResultResponse;
import com.pgplatform.owner.FloorService;
import com.pgplatform.owner.GenderPreference;
import com.pgplatform.owner.PgService;
import com.pgplatform.owner.RoomService;
import com.pgplatform.owner.RoomType;
import com.pgplatform.owner.dto.FloorCreateRequest;
import com.pgplatform.owner.dto.PgCreateRequest;
import com.pgplatform.owner.dto.RoomCreateRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.math.BigDecimal;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class PgSearchServiceTest extends AbstractIntegrationTest {

    @Autowired
    private UserRepository userRepository;
    @Autowired
    private PgService pgService;
    @Autowired
    private FloorService floorService;
    @Autowired
    private RoomService roomService;
    @Autowired
    private PgSearchService pgSearchService;

    private UUID createOwner() {
        User owner = new User();
        owner.setEmail("owner-" + UUID.randomUUID() + "@example.com");
        owner.setFullName("Discovery Owner");
        owner.setRole(Role.OWNER);
        owner.setProvider(AuthProviderType.LOCAL);
        return userRepository.save(owner).getId();
    }

    @Test
    void searchFindsOnlyActivePgsMatchingFiltersWithCorrectAvailabilityAndRent() {
        UUID ownerId = createOwner();
        UUID pgId = pgService.create(ownerId, new PgCreateRequest("Hilltop PG", "5 Hill Rd", "Chennai",
                null, null, 13.08, 80.27, "Quiet PG near tech park", GenderPreference.FEMALE)).id();
        UUID floorId = floorService.create(pgId, ownerId, new FloorCreateRequest("Ground Floor", 0)).id();
        roomService.create(floorId, ownerId, new RoomCreateRequest("G1", 2, new BigDecimal("8000.00"), RoomType.NON_AC));
        roomService.create(floorId, ownerId, new RoomCreateRequest("G2", 1, new BigDecimal("12000.00"), RoomType.AC));

        PagedResponse<PgSearchResultResponse> results = pgSearchService.search("Chennai", GenderPreference.FEMALE,
                null, null, 0, 20);
        assertThat(results.content()).hasSize(1);
        PgSearchResultResponse result = results.content().get(0);
        assertThat(result.availableBeds()).isEqualTo(3);
        assertThat(result.minRentPerBed()).isEqualByComparingTo("8000.00");
        assertThat(result.maxRentPerBed()).isEqualByComparingTo("12000.00");

        assertThat(pgSearchService.search("Chennai", GenderPreference.MALE, null, null, 0, 20).content()).isEmpty();
        assertThat(pgSearchService.search(null, null, new BigDecimal("15000"), null, 0, 20).content()).isEmpty();
        assertThat(pgSearchService.search("chennai", null, null, null, 0, 20).content()).hasSize(1); // case-insensitive city match

        PgDetailsResponse details = pgSearchService.getDetails(pgId);
        assertThat(details.totalBeds()).isEqualTo(3);
        assertThat(details.availableBeds()).isEqualTo(3);
        assertThat(details.floors()).hasSize(1);
        assertThat(details.floors().get(0).rooms()).hasSize(2);

        assertThatThrownBy(() -> pgSearchService.getDetails(UUID.randomUUID())).isInstanceOf(NotFoundException.class);
    }
}
