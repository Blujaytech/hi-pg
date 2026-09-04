package com.pgplatform.owner;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.AuthProviderType;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.owner.dto.FloorCreateRequest;
import com.pgplatform.owner.dto.PgCreateRequest;
import com.pgplatform.owner.dto.RoomCreateRequest;
import com.pgplatform.owner.dto.RoomResponse;
import com.pgplatform.owner.dto.RoomUpdateRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.math.BigDecimal;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Proves the core Phase 2 business rule: a room's beds are auto-created from
 * its sharing_count, and grow/shrink to match when sharing_count changes,
 * refusing to shrink below the number of occupied beds.
 */
class RoomBedAutoCreationTest extends AbstractIntegrationTest {

    @Autowired
    private UserRepository userRepository;
    @Autowired
    private PasswordEncoder passwordEncoder;
    @Autowired
    private PgService pgService;
    @Autowired
    private FloorService floorService;
    @Autowired
    private RoomService roomService;
    @Autowired
    private BedRepository bedRepository;

    private UUID createOwner() {
        User owner = new User();
        owner.setEmail("owner-" + UUID.randomUUID() + "@example.com");
        owner.setFullName("Test Owner");
        owner.setPasswordHash(passwordEncoder.encode("password123"));
        owner.setRole(Role.OWNER);
        owner.setProvider(AuthProviderType.LOCAL);
        return userRepository.save(owner).getId();
    }

    @Test
    void creatingARoomAutoCreatesOneBedPerSharingCount() {
        UUID ownerId = createOwner();
        UUID pgId = pgService.create(ownerId, new PgCreateRequest("Sunrise PG", "12 MG Road", "Bengaluru",
                "KA", "560001", null, null, null, GenderPreference.CO_ED)).id();
        UUID floorId = floorService.create(pgId, ownerId, new FloorCreateRequest("Ground Floor", 0)).id();

        RoomResponse room = roomService.create(floorId, ownerId, new RoomCreateRequest("G-01", 3, new BigDecimal("6000.00"), RoomType.NON_AC));

        assertThat(room.beds()).hasSize(3);
        assertThat(room.beds()).extracting("label").containsExactly("Bed 1", "Bed 2", "Bed 3");
        assertThat(room.beds()).allSatisfy(bed -> assertThat(bed.status()).isEqualTo(BedStatus.AVAILABLE));
    }

    @Test
    void increasingSharingCountAddsBedsAndDecreasingRemovesThem() {
        UUID ownerId = createOwner();
        UUID pgId = pgService.create(ownerId, new PgCreateRequest("Sunrise PG", "12 MG Road", "Bengaluru",
                null, null, null, null, null, GenderPreference.CO_ED)).id();
        UUID floorId = floorService.create(pgId, ownerId, new FloorCreateRequest("Ground Floor", 0)).id();
        RoomResponse room = roomService.create(floorId, ownerId, new RoomCreateRequest("G-01", 2, new BigDecimal("6000.00"), RoomType.NON_AC));

        RoomResponse grown = roomService.update(room.id(), ownerId, new RoomUpdateRequest("G-01", 4, new BigDecimal("6000.00"), RoomType.NON_AC));
        assertThat(grown.beds()).hasSize(4);

        RoomResponse shrunk = roomService.update(room.id(), ownerId, new RoomUpdateRequest("G-01", 1, new BigDecimal("6000.00"), RoomType.NON_AC));
        assertThat(shrunk.beds()).hasSize(1);
    }

    @Test
    void cannotShrinkSharingCountBelowOccupiedBedCount() {
        UUID ownerId = createOwner();
        UUID pgId = pgService.create(ownerId, new PgCreateRequest("Sunrise PG", "12 MG Road", "Bengaluru",
                null, null, null, null, null, GenderPreference.CO_ED)).id();
        UUID floorId = floorService.create(pgId, ownerId, new FloorCreateRequest("Ground Floor", 0)).id();
        RoomResponse room = roomService.create(floorId, ownerId, new RoomCreateRequest("G-01", 2, new BigDecimal("6000.00"), RoomType.NON_AC));

        // Occupy both beds.
        room.beds().forEach(bed -> {
            Bed entity = bedRepository.findByIdAndDeletedAtIsNull(bed.id()).orElseThrow();
            entity.setStatus(BedStatus.OCCUPIED);
            bedRepository.save(entity);
        });

        assertThatThrownBy(() ->
                roomService.update(room.id(), ownerId, new RoomUpdateRequest("G-01", 1, new BigDecimal("6000.00"), RoomType.NON_AC))
        ).isInstanceOf(com.pgplatform.common.ConflictException.class);
    }
}
