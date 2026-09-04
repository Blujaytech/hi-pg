package com.pgplatform.owner;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.AuthProviderType;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.common.ForbiddenException;
import com.pgplatform.owner.dto.PgCreateRequest;
import com.pgplatform.owner.dto.PgUpdateRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** Proves §7 item 6: one owner can never read or mutate another owner's PG. */
class OwnershipGuardIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    private UserRepository userRepository;
    @Autowired
    private PgService pgService;

    private UUID createOwner(String email) {
        User owner = new User();
        owner.setEmail(email);
        owner.setFullName("Owner " + email);
        owner.setRole(Role.OWNER);
        owner.setProvider(AuthProviderType.LOCAL);
        return userRepository.save(owner).getId();
    }

    @Test
    void ownerBCannotReadOrUpdateOwnerAsPg() {
        UUID ownerA = createOwner("a-" + UUID.randomUUID() + "@example.com");
        UUID ownerB = createOwner("b-" + UUID.randomUUID() + "@example.com");

        UUID pgId = pgService.create(ownerA, new PgCreateRequest("Owner A's PG", "Street 1", "Pune",
                null, null, null, null, null, GenderPreference.CO_ED)).id();

        assertThatThrownBy(() -> pgService.getOwned(pgId, ownerB)).isInstanceOf(ForbiddenException.class);
        assertThatThrownBy(() -> pgService.update(pgId, ownerB,
                new PgUpdateRequest("Hijacked", "x", "x", null, null, null, null, null,
                        GenderPreference.CO_ED, PgStatus.ACTIVE))
        ).isInstanceOf(ForbiddenException.class);
    }
}
