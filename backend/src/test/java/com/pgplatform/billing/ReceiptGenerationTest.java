package com.pgplatform.billing;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.AuthProviderType;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.billing.dto.FeeCreateRequest;
import com.pgplatform.billing.dto.FeeResponse;
import com.pgplatform.billing.dto.PaymentCreateRequest;
import com.pgplatform.billing.dto.ReceiptResponse;
import com.pgplatform.common.ForbiddenException;
import com.pgplatform.owner.GenderPreference;
import com.pgplatform.owner.PgService;
import com.pgplatform.owner.dto.PgCreateRequest;
import com.pgplatform.student.StudentService;
import com.pgplatform.student.dto.StudentCreateRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ReceiptGenerationTest extends AbstractIntegrationTest {

    @Autowired
    private UserRepository userRepository;
    @Autowired
    private PgService pgService;
    @Autowired
    private StudentService studentService;
    @Autowired
    private FeeService feeService;
    @Autowired
    private ReceiptService receiptService;

    @Test
    void everyPaymentGetsExactlyOneReceiptWithASequentialNumber() {
        User owner = new User();
        owner.setEmail("owner-" + UUID.randomUUID() + "@example.com");
        owner.setFullName("Test Owner");
        owner.setRole(Role.OWNER);
        owner.setProvider(AuthProviderType.LOCAL);
        UUID ownerId = userRepository.save(owner).getId();

        UUID pgId = pgService.create(ownerId, new PgCreateRequest("Sunrise PG", "12 MG Road", "Bengaluru",
                null, null, null, null, null, GenderPreference.CO_ED)).id();
        UUID studentId = studentService.create(pgId, ownerId, new StudentCreateRequest(
                "Asha Rao", "9999999999", null, null, null, null, null, LocalDate.now(), null)).id();

        FeeResponse fee = feeService.create(studentId, ownerId, new FeeCreateRequest(
                1, 2026, new BigDecimal("6000.00"), LocalDate.now().plusDays(5), null));

        feeService.recordPayment(fee.id(), ownerId, new PaymentCreateRequest(
                new BigDecimal("2000.00"), LocalDate.now(), PaymentMethod.CASH, null, null));
        feeService.recordPayment(fee.id(), ownerId, new PaymentCreateRequest(
                new BigDecimal("4000.00"), LocalDate.now(), PaymentMethod.UPI, "txn1", null));

        List<ReceiptResponse> receipts = receiptService.listForStudent(studentId, ownerId);
        assertThat(receipts).hasSize(2);
        assertThat(receipts).extracting("receiptNumber").doesNotHaveDuplicates();
        assertThat(receipts.get(0).receiptNumber()).startsWith("RCPT-" + LocalDate.now().getYear() + "-");
        assertThat(receipts).allSatisfy(r -> assertThat(r.studentName()).isEqualTo("Asha Rao"));

        assertThatThrownBy(() -> receiptService.get(receipts.get(0).id(), UUID.randomUUID()))
                .isInstanceOf(ForbiddenException.class);
    }
}
