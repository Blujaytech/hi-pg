package com.pgplatform.billing;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.AuthProviderType;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.billing.dto.FeeCreateRequest;
import com.pgplatform.billing.dto.FeeResponse;
import com.pgplatform.billing.dto.PaymentCreateRequest;
import com.pgplatform.common.ConflictException;
import com.pgplatform.owner.GenderPreference;
import com.pgplatform.owner.PgService;
import com.pgplatform.owner.dto.PgCreateRequest;
import com.pgplatform.student.StudentService;
import com.pgplatform.student.dto.StudentCreateRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class FeePaymentTest extends AbstractIntegrationTest {

    @Autowired
    private UserRepository userRepository;
    @Autowired
    private PgService pgService;
    @Autowired
    private StudentService studentService;
    @Autowired
    private FeeService feeService;

    private UUID ownerId;
    private UUID studentId;

    private void setUp() {
        User owner = new User();
        owner.setEmail("owner-" + UUID.randomUUID() + "@example.com");
        owner.setFullName("Test Owner");
        owner.setRole(Role.OWNER);
        owner.setProvider(AuthProviderType.LOCAL);
        ownerId = userRepository.save(owner).getId();

        UUID pgId = pgService.create(ownerId, new PgCreateRequest("Sunrise PG", "12 MG Road", "Bengaluru",
                null, null, null, null, null, GenderPreference.CO_ED)).id();

        studentId = studentService.create(pgId, ownerId, new StudentCreateRequest(
                "Asha Rao", "9999999999", null, null, null, null, null, LocalDate.now(), null)).id();
    }

    @Test
    void partialThenFullPaymentMovesFeeThroughStatuses() {
        setUp();
        FeeResponse fee = feeService.create(studentId, ownerId, new FeeCreateRequest(
                1, 2026, new BigDecimal("6000.00"), LocalDate.now().plusDays(5), null));
        assertThat(fee.status()).isEqualTo(FeeStatus.PENDING);

        FeeResponse afterPartial = feeService.recordPayment(fee.id(), ownerId, new PaymentCreateRequest(
                new BigDecimal("2000.00"), LocalDate.now(), PaymentMethod.CASH, null, null));
        assertThat(afterPartial.status()).isEqualTo(FeeStatus.PARTIALLY_PAID);
        assertThat(afterPartial.balance()).isEqualByComparingTo("4000.00");

        FeeResponse afterFull = feeService.recordPayment(fee.id(), ownerId, new PaymentCreateRequest(
                new BigDecimal("4000.00"), LocalDate.now(), PaymentMethod.UPI, "txn123", null));
        assertThat(afterFull.status()).isEqualTo(FeeStatus.PAID);
        assertThat(afterFull.balance()).isEqualByComparingTo("0.00");
        assertThat(afterFull.payments()).hasSize(2);
    }

    @Test
    void cannotCreateTwoFeesForTheSameStudentAndPeriod() {
        setUp();
        feeService.create(studentId, ownerId, new FeeCreateRequest(1, 2026, new BigDecimal("6000.00"), LocalDate.now().plusDays(5), null));

        assertThatThrownBy(() ->
                feeService.create(studentId, ownerId, new FeeCreateRequest(1, 2026, new BigDecimal("6000.00"), LocalDate.now().plusDays(5), null))
        ).isInstanceOf(ConflictException.class);
    }

    @Test
    void overdueIsDerivedNotStored() {
        setUp();
        FeeResponse fee = feeService.create(studentId, ownerId, new FeeCreateRequest(
                1, 2026, new BigDecimal("6000.00"), LocalDate.now().minusDays(1), null));
        assertThat(fee.overdue()).isTrue();
        assertThat(fee.status()).isEqualTo(FeeStatus.PENDING);
    }
}
