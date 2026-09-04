package com.pgplatform.payment;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.AuthProviderType;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.billing.Fee;
import com.pgplatform.billing.FeeRepository;
import com.pgplatform.billing.FeeService;
import com.pgplatform.billing.PaymentRepository;
import com.pgplatform.billing.dto.FeeCreateRequest;
import com.pgplatform.billing.dto.FeeResponse;
import com.pgplatform.common.ForbiddenException;
import com.pgplatform.owner.GenderPreference;
import com.pgplatform.owner.PgService;
import com.pgplatform.owner.dto.PgCreateRequest;
import com.pgplatform.payment.dto.PaymentOrderCreateRequest;
import com.pgplatform.payment.dto.PaymentOrderResponse;
import com.pgplatform.student.StudentService;
import com.pgplatform.student.dto.StudentCreateRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class PaymentOrderServiceTest extends AbstractIntegrationTest {

    @Autowired
    private UserRepository userRepository;
    @Autowired
    private PgService pgService;
    @Autowired
    private StudentService studentService;
    @Autowired
    private FeeService feeService;
    @Autowired
    private FeeRepository feeRepository;
    @Autowired
    private PaymentOrderService paymentOrderService;
    @Autowired
    private PaymentOrderRepository paymentOrderRepository;
    @Autowired
    private PaymentRepository paymentRepository;

    private record FeeAndStudent(UUID feeId, UUID studentId) {
    }

    private FeeAndStudent setUpFee() {
        User owner = new User();
        owner.setEmail("owner-" + UUID.randomUUID() + "@example.com");
        owner.setFullName("Payment Owner");
        owner.setRole(Role.OWNER);
        owner.setProvider(AuthProviderType.LOCAL);
        UUID ownerId = userRepository.save(owner).getId();

        UUID pgId = pgService.create(ownerId, new PgCreateRequest("Payment PG", "9 Test Ave", "Delhi",
                null, null, null, null, null, GenderPreference.CO_ED)).id();
        UUID studentId = studentService.create(pgId, ownerId, new StudentCreateRequest(
                "Ravi Kumar", "9666666666", null, null, null, null, null, LocalDate.now(), null)).id();

        FeeResponse fee = feeService.create(studentId, ownerId, new FeeCreateRequest(
                LocalDate.now().getMonthValue(), LocalDate.now().getYear(),
                new BigDecimal("7500.00"), LocalDate.now().plusDays(5), null));
        return new FeeAndStudent(fee.id(), studentId);
    }

    @Test
    void creatingAnOrderCallsTheStubGatewayAndFailsWith501SinceNoRazorpayAccountIsConfigured() {
        FeeAndStudent f = setUpFee();

        assertThatThrownBy(() -> paymentOrderService.createOrder(f.feeId(), f.studentId(),
                new PaymentOrderCreateRequest(UUID.randomUUID().toString())))
                .isInstanceOf(UnsupportedOperationException.class);

        // No orphan row -- the gateway call happens before anything is persisted (same discipline as
        // DocumentService.upload, Phase 7b).
        assertThat(paymentOrderRepository.count()).isZero();
    }

    @Test
    void aRetriedRequestWithTheSameIdempotencyKeyReturnsTheExistingOrderWithoutCallingTheGatewayAgain() {
        FeeAndStudent f = setUpFee();
        String idempotencyKey = UUID.randomUUID().toString();
        Fee fee = feeRepository.findByIdAndDeletedAtIsNull(f.feeId()).orElseThrow();

        // Simulate an order that was already created successfully (as if a real gateway had responded) --
        // this is what createOrder() would have persisted had the stub not thrown.
        PaymentOrder existing = new PaymentOrder();
        existing.setFee(fee);
        existing.setIdempotencyKey(idempotencyKey);
        existing.setAmount(new BigDecimal("7500.00"));
        existing.setCurrency("INR");
        existing.setStatus(PaymentOrderStatus.CREATED);
        existing.setRazorpayOrderId("order_test_123");
        paymentOrderRepository.save(existing);

        PaymentOrderResponse response = paymentOrderService.createOrder(f.feeId(), f.studentId(),
                new PaymentOrderCreateRequest(idempotencyKey));

        assertThat(response.razorpayOrderId()).isEqualTo("order_test_123");
        assertThat(paymentOrderRepository.count()).isEqualTo(1); // no second row created
    }

    @Test
    void creatingAnOrderForSomeoneElsesFeeIsForbidden() {
        FeeAndStudent f = setUpFee();

        assertThatThrownBy(() -> paymentOrderService.createOrder(f.feeId(), UUID.randomUUID(),
                new PaymentOrderCreateRequest(UUID.randomUUID().toString())))
                .isInstanceOf(ForbiddenException.class);
    }

    @Test
    void reusingAnotherStudentsIdempotencyKeyIsForbiddenRatherThanHandingBackTheirOrder() {
        // Phase 15 security audit finding (see docs/decisions.md ADR-0022): idempotency_key
        // is unique globally, not per-student (V10 migration), so the early-return path in
        // createOrder() must re-check ownership too -- otherwise a client that (accidentally
        // or deliberately) reused another student's key would be handed back that student's
        // order details instead of a fresh 403.
        FeeAndStudent f = setUpFee();
        String idempotencyKey = UUID.randomUUID().toString();
        Fee fee = feeRepository.findByIdAndDeletedAtIsNull(f.feeId()).orElseThrow();

        PaymentOrder existing = new PaymentOrder();
        existing.setFee(fee);
        existing.setIdempotencyKey(idempotencyKey);
        existing.setAmount(new BigDecimal("7500.00"));
        existing.setCurrency("INR");
        existing.setStatus(PaymentOrderStatus.CREATED);
        existing.setRazorpayOrderId("order_owned_by_someone_else");
        paymentOrderRepository.save(existing);

        UUID differentStudentId = UUID.randomUUID();
        assertThatThrownBy(() -> paymentOrderService.createOrder(f.feeId(), differentStudentId,
                new PaymentOrderCreateRequest(idempotencyKey)))
                .isInstanceOf(ForbiddenException.class);
    }

    @Test
    void webhookProcessingRecordsAPaymentAndIsIdempotentOnRedelivery() {
        FeeAndStudent f = setUpFee();
        Fee fee = feeRepository.findByIdAndDeletedAtIsNull(f.feeId()).orElseThrow();

        PaymentOrder order = new PaymentOrder();
        order.setFee(fee);
        order.setIdempotencyKey(UUID.randomUUID().toString());
        order.setAmount(new BigDecimal("7500.00"));
        order.setCurrency("INR");
        order.setStatus(PaymentOrderStatus.CREATED);
        order.setRazorpayOrderId("order_webhook_test");
        paymentOrderRepository.save(order);

        paymentOrderService.handleWebhookPayload("order_webhook_test", "pay_test_1", true);
        assertThat(paymentOrderRepository.findByRazorpayOrderIdAndDeletedAtIsNull("order_webhook_test").orElseThrow().getStatus())
                .isEqualTo(PaymentOrderStatus.PAID);
        assertThat(paymentRepository.findAllByFeeIdAndDeletedAtIsNullOrderByPaidOnDesc(f.feeId())).hasSize(1);

        // Razorpay redelivers the same webhook -- must not double-record the payment.
        paymentOrderService.handleWebhookPayload("order_webhook_test", "pay_test_1", true);
        assertThat(paymentRepository.findAllByFeeIdAndDeletedAtIsNullOrderByPaidOnDesc(f.feeId())).hasSize(1);
    }

    @Test
    void webhookForAnUnknownOrderIsIgnoredRatherThanThrowing() {
        assertThat(paymentOrderRepository.count()).isZero();
        paymentOrderService.handleWebhookPayload("order_does_not_exist", "pay_x", true);
        // no exception, nothing to assert beyond "didn't blow up"
    }
}
