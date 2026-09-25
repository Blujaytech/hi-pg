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
import com.pgplatform.discovery.dto.BedSeatSummary;
import com.pgplatform.discovery.dto.RoomAvailabilityResponse;
import com.pgplatform.owner.BedRepository;
import com.pgplatform.owner.BedStatus;
import com.pgplatform.owner.FloorService;
import com.pgplatform.owner.GenderPreference;
import com.pgplatform.owner.PgService;
import com.pgplatform.owner.RoomBookingMode;
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
    @Autowired
    private BedRepository bedRepository;

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

        PagedResponse<PgSearchResultResponse> results = pgSearchService.search(null, "Chennai", GenderPreference.FEMALE,
                null, null, 0, 20);
        assertThat(results.content()).hasSize(1);
        PgSearchResultResponse result = results.content().get(0);
        assertThat(result.availableBeds()).isEqualTo(3);
        assertThat(result.minRentPerBed()).isEqualByComparingTo("8000.00");
        assertThat(result.maxRentPerBed()).isEqualByComparingTo("12000.00");

        assertThat(pgSearchService.search(null, "Chennai", GenderPreference.MALE, null, null, 0, 20).content()).isEmpty();
        assertThat(pgSearchService.search(null, null, null, new BigDecimal("15000"), null, 0, 20).content()).isEmpty();
        assertThat(pgSearchService.search(null, "chennai", null, null, null, 0, 20).content()).hasSize(1); // case-insensitive city match

        PgDetailsResponse details = pgSearchService.getDetails(pgId);
        assertThat(details.totalBeds()).isEqualTo(3);
        assertThat(details.availableBeds()).isEqualTo(3);
        assertThat(details.directPaymentAvailable()).isFalse();
        assertThat(details.floors()).hasSize(1);
        assertThat(details.floors().get(0).rooms()).hasSize(2);

        assertThatThrownBy(() -> pgSearchService.getDetails(UUID.randomUUID())).isInstanceOf(NotFoundException.class);
    }

    @Test
    void freeTextSearchMatchesNameAddressAndCityWordByWord() {
        UUID ownerId = createOwner();
        // A made-up locality keeps this test independent of PGs other tests create.
        String area = "zq" + UUID.randomUUID().toString().substring(0, 8);
        pgService.create(ownerId, new PgCreateRequest("Residency " + area, "Road 1", "Hyderabad",
                null, "500038", null, null, null, GenderPreference.FEMALE));
        pgService.create(ownerId, new PgCreateRequest("Green Valley PG", "near " + area + " Metro", "Hyderabad",
                null, null, null, null, null, GenderPreference.MALE));

        // One word, matched in the name of one PG and the address of the other.
        PagedResponse<PgSearchResultResponse> byArea = pgSearchService.search(area, null, null, null, null, 0, 20);
        assertThat(byArea.content()).hasSize(2);
        assertThat(byArea.totalElements()).isEqualTo(2);
        // Case-insensitive and partial.
        assertThat(pgSearchService.search(area.toUpperCase().substring(0, 7), null, null, null, null, 0, 50)
                .content()).extracting(PgSearchResultResponse::name).contains("Residency " + area, "Green Valley PG");

        // Every word has to match somewhere.
        assertThat(pgSearchService.search(area + " metro", null, null, null, null, 0, 20).content())
                .extracting(PgSearchResultResponse::name).containsExactly("Green Valley PG");
        assertThat(pgSearchService.search("residency " + area, null, null, null, null, 0, 20).content())
                .extracting(PgSearchResultResponse::name).containsExactly("Residency " + area);
        assertThat(pgSearchService.search(area + " 500038", null, null, null, null, 0, 20).content()).hasSize(1);

        // Combines with the other filters.
        assertThat(pgSearchService.search(area, null, GenderPreference.MALE, null, null, 0, 20).content())
                .extracting(PgSearchResultResponse::name).containsExactly("Green Valley PG");

        // LIKE wildcards typed by a user are literal, not wildcards.
        assertThat(pgSearchService.search("%" + area, null, null, null, null, 0, 20).content()).isEmpty();
        assertThat(pgSearchService.search(area.replace('q', '_'), null, null, null, null, 0, 20).content()).isEmpty();
    }

    @Test
    void searchReportsStayTypesAndDetailsListEveryBedWithItsAvailability() {
        UUID ownerId = createOwner();
        String city = "Bengaluru";
        UUID mixedPgId = pgService.create(ownerId, new PgCreateRequest("Mixed Stay PG", "1 Main Rd", city,
                null, null, null, null, null, GenderPreference.CO_ED)).id();
        UUID floorId = floorService.create(mixedPgId, ownerId, new FloorCreateRequest("Ground Floor", 0)).id();
        roomService.create(floorId, ownerId, new RoomCreateRequest("M1", 3, new BigDecimal("7000.00"),
                RoomType.NON_AC, RoomBookingMode.MIXED, new BigDecimal("500.00"), 15, BigDecimal.ZERO));
        UUID monthlyPgId = pgService.create(ownerId, new PgCreateRequest("Monthly Only PG", "2 Main Rd", city,
                null, null, null, null, null, GenderPreference.CO_ED)).id();
        UUID monthlyFloorId = floorService.create(monthlyPgId, ownerId, new FloorCreateRequest("Ground Floor", 0)).id();
        roomService.create(monthlyFloorId, ownerId, new RoomCreateRequest("A1", 2, new BigDecimal("6000.00"), RoomType.AC));

        PagedResponse<PgSearchResultResponse> results = pgSearchService.search(null, city, null, null, null, 0, 20);
        PgSearchResultResponse mixed = results.content().stream()
                .filter(pg -> pg.id().equals(mixedPgId)).findFirst().orElseThrow();
        assertThat(mixed.offersMonthly()).isTrue();
        assertThat(mixed.offersDayWise()).isTrue();
        assertThat(mixed.minDayWiseRate()).isEqualByComparingTo("500.00");
        PgSearchResultResponse monthly = results.content().stream()
                .filter(pg -> pg.id().equals(monthlyPgId)).findFirst().orElseThrow();
        assertThat(monthly.offersMonthly()).isTrue();
        assertThat(monthly.offersDayWise()).isFalse();
        assertThat(monthly.minDayWiseRate()).isNull();

        // Take one bed out of service: it stays in the room's bed map, marked unavailable.
        RoomAvailabilityResponse room = pgSearchService.getDetails(mixedPgId).floors().get(0).rooms().get(0);
        UUID takenBedId = room.beds().get(1).id();
        bedRepository.findById(takenBedId).ifPresent(bed -> {
            bed.setStatus(BedStatus.MAINTENANCE);
            bedRepository.save(bed);
        });

        room = pgSearchService.getDetails(mixedPgId).floors().get(0).rooms().get(0);
        assertThat(room.beds()).hasSize(3);
        assertThat(room.beds()).extracting(BedSeatSummary::label).containsExactly("Bed 1", "Bed 2", "Bed 3");
        assertThat(room.beds()).filteredOn(BedSeatSummary::available).hasSize(2);
        assertThat(room.beds()).filteredOn(bed -> !bed.available())
                .extracting(BedSeatSummary::id).containsExactly(takenBedId);
        assertThat(room.availableBedOptions()).hasSize(2);
    }
}
