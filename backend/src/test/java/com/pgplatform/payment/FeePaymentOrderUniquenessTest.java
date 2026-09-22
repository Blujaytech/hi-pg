package com.pgplatform.payment;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.AuthProviderType;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.billing.Fee;
import com.pgplatform.billing.FeeRepository;
import com.pgplatform.billing.FeeService;
import com.pgplatform.billing.dto.FeeCreateRequest;
import com.pgplatform.billing.dto.FeeResponse;
import com.pgplatform.owner.GenderPreference;
import com.pgplatform.owner.PgService;
import com.pgplatform.owner.dto.PgCreateRequest;
import com.pgplatform.student.StudentService;
import com.pgplatform.student.dto.StudentCreateRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * V16 gave bookings "at most one open checkout" at the database level; fees
 * never got the equivalent, so two concurrent POSTs to
 * /student/fees/{id}/payment-orders -- what a double tap on "Pay now"
 * produces -- could both pass the service's "is there an open order?" read
 * and create two payable Razorpay orders for one fee. The customer can then
 * be charged twice, and only the second capture's payment_over_allocation
 * warning catches it, needing manual reconciliation.
 *
 * V20 closes that with a partial unique index. These tests pin both halves of
 * it: the duplicate is impossible, and the cases that legitimately need a
 * second order still work.
 */
class FeePaymentOrderUniquenessTest extends AbstractIntegrationTest {

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
    private PaymentOrderRepository paymentOrderRepository;

    @Test
    void oneFeeCannotHaveTwoOpenCheckoutsAtOnce() {
        Fee fee = setUpFee();
        paymentOrderRepository.saveAndFlush(
                openOrder(fee, "order_first", PaymentOrderStatus.CREATED));

        assertThatThrownBy(() -> paymentOrderRepository.saveAndFlush(
                openOrder(fee, "order_second", PaymentOrderStatus.CREATED)))
                .as("the second live Razorpay order for one fee is what double-charges the customer")
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void aFailedAttemptCanBeRetriedWithANewOrder() {
        Fee fee = setUpFee();
        PaymentOrder failed = openOrder(fee, "order_failed", PaymentOrderStatus.CREATED);
        failed.setStatus(PaymentOrderStatus.FAILED);
        failed.setFailureReason("Payment not captured");
        paymentOrderRepository.saveAndFlush(failed);

        paymentOrderRepository.saveAndFlush(
                openOrder(fee, "order_retry", PaymentOrderStatus.CREATED));

        assertThat(paymentOrderRepository.count()).isEqualTo(2);
    }

    @Test
    void aPartiallyPaidFeeCanStillOpenAnOrderForTheRemainingBalance() {
        Fee fee = setUpFee();
        PaymentOrder paid = openOrder(fee, "order_part_paid", PaymentOrderStatus.CREATED);
        paid.setStatus(PaymentOrderStatus.PAID);
        paid.setPaidAt(Instant.now());
        paid.setAmount(new BigDecimal("2500.00"));
        paymentOrderRepository.saveAndFlush(paid);

        // PAID is deliberately outside the index: the rest of the rent still
        // has to be payable.
        paymentOrderRepository.saveAndFlush(
                openOrder(fee, "order_balance", PaymentOrderStatus.CREATED));

        assertThat(paymentOrderRepository.count()).isEqualTo(2);
    }

    @Test
    void twoDifferentFeesAreUnaffected() {
        Fee first = setUpFee();
        UUID ownerId = jdbcTemplate.queryForObject(
                "select owner_id from pgs where id = ?", UUID.class, first.getPg().getId());
        Fee second = feeRepository.findByIdAndDeletedAtIsNull(
                feeService.create(first.getStudent().getId(), ownerId,
                        new FeeCreateRequest(monthAfter(), LocalDate.now().getYear(),
                                new BigDecimal("7500.00"), LocalDate.now().plusDays(35), null)).id())
                .orElseThrow();

        paymentOrderRepository.saveAndFlush(openOrder(first, "order_a", PaymentOrderStatus.CREATED));
        paymentOrderRepository.saveAndFlush(openOrder(second, "order_b", PaymentOrderStatus.CREATED));

        assertThat(paymentOrderRepository.count()).isEqualTo(2);
    }

    private int monthAfter() {
        return LocalDate.now().getMonthValue() == 12 ? 1 : LocalDate.now().getMonthValue() + 1;
    }

    private PaymentOrder openOrder(Fee fee, String razorpayOrderId, PaymentOrderStatus status) {
        PaymentOrder order = new PaymentOrder();
        order.setFee(fee);
        order.setPurpose(PaymentPurpose.FEE);
        order.setIdempotencyKey(UUID.randomUUID().toString());
        order.setAmount(new BigDecimal("7500.00"));
        order.setCurrency("INR");
        order.setStatus(status);
        order.setRazorpayOrderId(razorpayOrderId);
        return order;
    }

    private Fee setUpFee() {
        User owner = new User();
        owner.setEmail("owner-" + UUID.randomUUID() + "@example.com");
        owner.setFullName("Uniqueness Owner");
        owner.setRole(Role.OWNER);
        owner.setProvider(AuthProviderType.LOCAL);
        UUID ownerId = userRepository.save(owner).getId();

        UUID pgId = pgService.create(ownerId, new PgCreateRequest("Uniqueness PG", "3 Test Ave", "Pune",
                null, null, null, null, null, GenderPreference.CO_ED)).id();
        UUID studentId = studentService.create(pgId, ownerId, new StudentCreateRequest(
                "Meera Nair", "9555555555", null, null, null, null, null, LocalDate.now(), null)).id();

        FeeResponse fee = feeService.create(studentId, ownerId, new FeeCreateRequest(
                LocalDate.now().getMonthValue(), LocalDate.now().getYear(),
                new BigDecimal("7500.00"), LocalDate.now().plusDays(5), null));
        return feeRepository.findByIdAndDeletedAtIsNull(fee.id()).orElseThrow();
    }
}
