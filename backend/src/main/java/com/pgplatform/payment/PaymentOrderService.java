package com.pgplatform.payment;

import com.pgplatform.billing.Fee;
import com.pgplatform.billing.FeeRepository;
import com.pgplatform.billing.FeeService;
import com.pgplatform.billing.FeeStatus;
import com.pgplatform.billing.PaymentMethod;
import com.pgplatform.billing.PaymentRepository;
import com.pgplatform.billing.dto.PaymentCreateRequest;
import com.pgplatform.common.ConflictException;
import com.pgplatform.common.ForbiddenException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.notification.NotificationService;
import com.pgplatform.payment.dto.PaymentOrderCreateRequest;
import com.pgplatform.payment.dto.PaymentOrderResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

/**
 * Phase 12. Two halves with very different maturity:
 *  - createOrder: needs a real Razorpay account (RazorpayGateway is
 *    stubbed) -- see docs/decisions.md ADR-0019.
 *  - handleWebhookPayload: fully implemented and tested today (signature
 *    verification + idempotent processing), independent of whether a real
 *    Razorpay order was ever created, since it's exercised directly by
 *    RazorpayWebhookServiceTest with a synthetic payload.
 */
@Service
public class PaymentOrderService {

    private static final Logger log = LoggerFactory.getLogger(PaymentOrderService.class);
    // Phase 15 security audit finding (technical plan §8) -- same "structured, separately
    // routable log line per access" approach as DocumentService's AUDIT logger.
    private static final Logger AUDIT = LoggerFactory.getLogger("AUDIT.payment");

    private final PaymentOrderRepository paymentOrderRepository;
    private final FeeRepository feeRepository;
    private final PaymentRepository paymentRepository;
    private final FeeService feeService;
    private final RazorpayGateway razorpayGateway;
    private final NotificationService notificationService;

    public PaymentOrderService(PaymentOrderRepository paymentOrderRepository, FeeRepository feeRepository,
                                PaymentRepository paymentRepository, FeeService feeService,
                                RazorpayGateway razorpayGateway, NotificationService notificationService) {
        this.paymentOrderRepository = paymentOrderRepository;
        this.feeRepository = feeRepository;
        this.paymentRepository = paymentRepository;
        this.feeService = feeService;
        this.razorpayGateway = razorpayGateway;
        this.notificationService = notificationService;
    }

    /**
     * Idempotent by {@code idempotencyKey}: a retried request with the same
     * key (e.g. after the client never saw the first response) returns the
     * existing order instead of calling Razorpay again or double-charging.
     */
    @Transactional
    public PaymentOrderResponse createOrder(UUID feeId, UUID studentId, PaymentOrderCreateRequest request) {
        // Phase 15 security audit finding: idempotencyKey is unique across
        // ALL students (V10's uq_payment_orders_idempotency_key is global,
        // not per-student), so the early-return path must re-check
        // ownership too -- otherwise a client that reused another
        // student's key (accidentally, or by guessing a low-entropy value)
        // would be handed back that student's order details. Checked here
        // even though createOrder always throws before this can be
        // exercised today (StubRazorpayGateway), because this is exactly
        // the kind of gap that must be closed before the stub is replaced,
        // not after. See docs/decisions.md ADR-0022.
        var existing = paymentOrderRepository.findByIdempotencyKeyAndDeletedAtIsNull(request.idempotencyKey());
        if (existing.isPresent()) {
            PaymentOrder order = existing.get();
            if (!order.getFee().getStudent().getId().equals(studentId)) {
                throw new ForbiddenException("This payment order does not belong to you");
            }
            return PaymentOrderResponse.from(order);
        }

        Fee fee = feeRepository.findByIdAndDeletedAtIsNull(feeId)
                .orElseThrow(() -> new NotFoundException("Fee not found"));
        if (!fee.getStudent().getId().equals(studentId)) {
            throw new ForbiddenException("This fee does not belong to you");
        }
        if (fee.getStatus() == FeeStatus.PAID) {
            throw new ConflictException("This fee is already fully paid");
        }

        BigDecimal alreadyPaid = paymentRepository.sumPaidForFee(feeId);
        BigDecimal balance = fee.getAmount().subtract(alreadyPaid);
        if (balance.compareTo(BigDecimal.ZERO) <= 0) {
            throw new ConflictException("This fee is already fully paid");
        }

        // Deliberately call the gateway before saving anything -- same
        // "no orphan row on failure" discipline as DocumentService.upload
        // (Phase 7b). Today this always throws (StubRazorpayGateway).
        RazorpayOrderResult result = razorpayGateway.createOrder(balance, "INR", "fee-" + feeId);

        PaymentOrder order = new PaymentOrder();
        order.setFee(fee);
        order.setIdempotencyKey(request.idempotencyKey());
        order.setAmount(balance);
        order.setCurrency("INR");
        order.setStatus(PaymentOrderStatus.CREATED);
        order.setRazorpayOrderId(result.razorpayOrderId());
        return PaymentOrderResponse.from(paymentOrderRepository.save(order));
    }

    /**
     * Called by RazorpayWebhookController after signature verification.
     * Safe to call twice with the same payload (Razorpay explicitly
     * recommends designing for redelivery) -- if the order is already PAID,
     * this is a no-op.
     */
    @Transactional
    public void handleWebhookPayload(String razorpayOrderId, String razorpayPaymentId, boolean captured) {
        PaymentOrder order = paymentOrderRepository.findByRazorpayOrderIdAndDeletedAtIsNull(razorpayOrderId)
                .orElse(null);
        if (order == null) {
            log.warn("Razorpay webhook for unknown order {} -- ignoring", razorpayOrderId);
            return;
        }
        if (order.getStatus() == PaymentOrderStatus.PAID) {
            log.info("Razorpay webhook for order {} already processed -- idempotent no-op", razorpayOrderId);
            return;
        }
        if (!captured) {
            order.setStatus(PaymentOrderStatus.FAILED);
            order.setFailureReason("Payment not captured");
            paymentOrderRepository.save(order);
            return;
        }

        order.setStatus(PaymentOrderStatus.PAID);
        order.setRazorpayPaymentId(razorpayPaymentId);
        paymentOrderRepository.save(order);
        AUDIT.info("action=payment_captured paymentOrderId={} feeId={} studentId={} amount={} razorpayPaymentId={}",
                order.getId(), order.getFee().getId(), order.getFee().getStudent().getId(), order.getAmount(), razorpayPaymentId);

        feeService.recordSystemPayment(order.getFee().getId(), new PaymentCreateRequest(
                order.getAmount(), LocalDate.now(), PaymentMethod.RAZORPAY, razorpayPaymentId,
                "Paid online via Razorpay (order " + razorpayOrderId + ")"
        ));

        var student = order.getFee().getStudent();
        if (student.getUser() != null) {
            notificationService.notifyUser(student.getUser().getId(), "Payment received",
                    "We received your online payment of " + order.getAmount() + " " + order.getCurrency() + ".");
        }
    }
}
