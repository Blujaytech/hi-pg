package com.pgplatform.expense;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.AuthProviderType;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.common.ForbiddenException;
import com.pgplatform.expense.dto.ExpenseCreateRequest;
import com.pgplatform.expense.dto.ExpenseResponse;
import com.pgplatform.owner.GenderPreference;
import com.pgplatform.owner.PgService;
import com.pgplatform.owner.dto.PgCreateRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ExpenseOwnershipTest extends AbstractIntegrationTest {

    @Autowired
    private UserRepository userRepository;
    @Autowired
    private PgService pgService;
    @Autowired
    private ExpenseService expenseService;

    private UUID createOwner(String email) {
        User owner = new User();
        owner.setEmail(email);
        owner.setFullName("Owner " + email);
        owner.setRole(Role.OWNER);
        owner.setProvider(AuthProviderType.LOCAL);
        return userRepository.save(owner).getId();
    }

    @Test
    void expenseIsListedForItsOwnerAndDeniedToAnotherOwner() {
        UUID ownerA = createOwner("a-" + UUID.randomUUID() + "@example.com");
        UUID ownerB = createOwner("b-" + UUID.randomUUID() + "@example.com");

        UUID pgId = pgService.create(ownerA, new PgCreateRequest("Sunrise PG", "12 MG Road", "Bengaluru",
                null, null, null, null, null, GenderPreference.CO_ED)).id();

        ExpenseResponse expense = expenseService.create(pgId, ownerA, new ExpenseCreateRequest(
                ExpenseCategory.MAINTENANCE, "Plumbing repair", new BigDecimal("1500.00"), LocalDate.now()));

        List<ExpenseResponse> listed = expenseService.listForPg(pgId, ownerA);
        assertThat(listed).extracting("id").contains(expense.id());

        assertThatThrownBy(() -> expenseService.listForPg(pgId, ownerB)).isInstanceOf(ForbiddenException.class);
    }
}
