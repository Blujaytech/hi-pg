package com.pgplatform.payment;

import com.pgplatform.billing.Fee;
import com.pgplatform.billing.FeeRepository;
import com.pgplatform.billing.FeeService;
import com.pgplatform.billing.FeeStatus;
import com.pgplatform.billing.PaymentMethod;
import com.pgplatform.billing.PaymentRepository;
import com.pgplatform.billing.dto.PaymentCreateRequest;
import com.pgplatform.booking.Booking;
import com.pgplatform.booking.BookingService;
import com.pgplatform.booking.BookingStatus;
import com.pgplatform.common.ConflictException;
import com.pgplatform.common.ForbiddenException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.notification.NotificationService;
import com.pgplatform.deposit.DepositService;
import com.pgplatform.owner.PaymentOnboardingStatus;
import com.pgplatform.owner.Pg;
import com.pgplatform.payment.dto.CheckoutVerificationRequest;
import com.pgplatform.payment.dto.PaymentOrderCreateRequest;
import com.pgplatform.payment.dto.PaymentOrderResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.UUID;

@Service
public class PaymentOrderService {

    private static final Logger log = LoggerFactory.getLogger(PaymentOrderService.class);
    private static final Logger AUDIT = LoggerFactory.getLogger("AUDIT.payment");

    private final PaymentOrderRepository paymentOrderRepository;
    private final FeeRepository feeRepository;
    private final PaymentRepository paymentRepository;
    private final FeeService feeService;
    private final BookingService bookingService;
    private final RazorpayGateway razorpayGateway;
    private final RazorpayProperties razorpayProperties;
    private final RazorpaySignatureVerifier signatureVerifier;
    private final NotificationService notificationService;
    private final DepositService depositService;

    public PaymentOrderService(PaymentOrderRepository paymentOrderRepository, FeeRepository feeRepository,
                               PaymentRepository paymentRepository, FeeService feeService,
                               BookingService bookingService, RazorpayGateway razorpayGateway,
                               RazorpayProperties razorpayProperties, RazorpaySignatureVerifier signatureVerifier,
                               NotificationService notificationService, DepositService depositService) {
        this.paymentOrderRepository = paymentOrderRepository;
        this.feeRepository = feeRepository;
        this.paymentRepository = paymentRepository;
        this.feeService = feeService;
        this.bookingService = bookingService;
        this.razorpayGateway = razorpayGateway;
        this.razorpayProperties = razorpayProperties;
        this.signatureVerifier = signatureVerifier;
        this.notificationService = notificationService;
        this.depositService = depositService;
    }

    @Transactional
    public PaymentOrderResponse createOrder(UUID feeId, UUID studentId, PaymentOrderCreateRequest request) {
        PaymentOrder existing = findOwnedExisting(request.idempotencyKey(), null, studentId);
        if (existing != null) {
            return response(existing);
        }

        Fee fee = feeRepository.findByIdAndDeletedAtIsNull(feeId)
                .orElseThrow(() -> new NotFoundException("Fee not found"));
        if (!fee.getStudent().getId().equals(studentId)) {
            throw new ForbiddenException("This fee does not belong to you");
        }
        if (fee.getStatus() == FeeStatus.PAID) {
            throw new ConflictException("This fee is already fully paid");
        }
        PaymentOrder openFeeOrder = paymentOrderRepository
                .findFirstByFeeIdAndStatusAndDeletedAtIsNullOrderByCreatedAtDesc(feeId, PaymentOrderStatus.CREATED)
                .orElse(null);
        if (openFeeOrder != null) {
            return response(openFeeOrder);
        }
        requirePaymentsEnabled(fee.getPg());

        BigDecimal balance = fee.getAmount().subtract(paymentRepository.sumPaidForFee(feeId));
        if (balance.compareTo(BigDecimal.ZERO) <= 0) {
            throw new ConflictException("This fee is already fully paid");
        }

        RazorpayOrderResult gatewayOrder = razorpayGateway.createOrder(balance, "INR", "fee-" + feeId);
        PaymentOrder order = baseOrder(request.idempotencyKey(), balance, gatewayOrder.razorpayOrderId());
        order.setFee(fee);
        order.setPurpose(PaymentPurpose.FEE);
        return response(paymentOrderRepository.save(order));
    }

    @Transactional
    public PaymentOrderResponse createBookingOrder(UUID bookingId, UUID userId, PaymentOrderCreateRequest request) {
        PaymentOrder existing = findOwnedExisting(request.idempotencyKey(), userId, null);
        if (existing != null) {
            return response(existing);
        }

        // The booking row lock makes RAZORPAY and DIRECT_UPI mutually exclusive,
        // even when the two buttons are tapped concurrently on different devices.
        Booking booking = bookingService.claimOnlinePaymentChannel(bookingId, userId);
        PaymentOrder openBookingOrder = paymentOrderRepository
                .findFirstByBookingIdAndStatusInAndDeletedAtIsNullOrderByCreatedAtDesc(bookingId,
                        java.util.List.of(PaymentOrderStatus.CREATED, PaymentOrderStatus.PAID))
                .orElse(null);
        if (openBookingOrder != null) {
            return response(openBookingOrder);
        }
        requirePaymentsEnabled(booking.getPg());

        RazorpayOrderResult gatewayOrder = razorpayGateway.createOrder(
                booking.getTotalAmount(), "INR", "booking-" + bookingId);
        PaymentOrder order = baseOrder(request.idempotencyKey(), booking.getTotalAmount(),
                gatewayOrder.razorpayOrderId());
        order.setBooking(booking);
        order.setPurpose(PaymentPurpose.BOOKING);
        return response(paymentOrderRepository.save(order));
    }

    /** Verifies the Checkout HMAC and captured status; webhooks remain the asynchronous fallback. */
    @Transactional
    public PaymentOrderResponse verifyCheckout(UUID paymentOrderId, UUID userId,
                                                CheckoutVerificationRequest request) {
        // Checkout callbacks and webhooks can arrive together. Serializing on the
        // payment-order row makes capture allocation and Route transfer exactly once.
        PaymentOrder order = paymentOrderRepository.findByIdForUpdate(paymentOrderId)
                .orElseThrow(() -> new NotFoundException("Payment order not found"));
        requireOwnedByUser(order, userId);

        String signedPayload = order.getRazorpayOrderId() + "|" + request.razorpayPaymentId();
        if (!signatureVerifier.isValid(signedPayload, request.razorpaySignature(),
                razorpayProperties.getKeySecret())) {
            throw new ForbiddenException("Razorpay payment signature is invalid");
        }
        if (!razorpayGateway.isPaymentCaptured(request.razorpayPaymentId())) {
            throw new ConflictException("Razorpay has not captured this payment");
        }
        processCapturedOrder(order, request.razorpayPaymentId());
        return response(order);
    }

    @Transactional
    public void handleWebhookPayload(String razorpayOrderId, String razorpayPaymentId, boolean captured) {
        PaymentOrder order = paymentOrderRepository.findByRazorpayOrderIdForUpdate(razorpayOrderId)
                .orElse(null);
        if (order == null) {
            log.warn("Razorpay webhook for unknown order {} -- ignoring", razorpayOrderId);
            return;
        }
        if (order.getStatus() == PaymentOrderStatus.PAID
                || order.getStatus() == PaymentOrderStatus.REFUND_PENDING
                || order.getStatus() == PaymentOrderStatus.REFUNDED) {
            return;
        }
        if (!captured) {
            order.setStatus(PaymentOrderStatus.FAILED);
            order.setFailureReason("Payment not captured");
            paymentOrderRepository.save(order);
            notifyPaymentFailure(order);
            return;
        }
        processCapturedOrder(order, razorpayPaymentId);
    }

    /** Records a recurring subscription charge and routes it to the PG owner. */
    @Transactional
    public void recordAutoPayCaptured(Fee fee, String razorpayPaymentId, String razorpayOrderId,
                                      BigDecimal capturedAmount) {
        String idempotencyKey = "autopay-" + razorpayPaymentId;
        if (paymentOrderRepository.findByIdempotencyKeyAndDeletedAtIsNull(idempotencyKey).isPresent()) {
            return;
        }
        BigDecimal balance = fee.getAmount().subtract(paymentRepository.sumPaidForFee(fee.getId()));
        BigDecimal allocated = capturedAmount.min(balance.max(BigDecimal.ZERO));

        PaymentOrder order = baseOrder(idempotencyKey, capturedAmount, razorpayOrderId);
        order.setFee(fee);
        order.setPurpose(PaymentPurpose.AUTOPAY);
        order.setStatus(PaymentOrderStatus.PAID);
        order.setPaidAt(Instant.now());
        order.setRazorpayPaymentId(razorpayPaymentId);
        order = paymentOrderRepository.save(order);

        if (allocated.compareTo(BigDecimal.ZERO) > 0) {
            feeService.recordSystemPayment(fee.getId(), new PaymentCreateRequest(
                    allocated, LocalDate.now(), PaymentMethod.RAZORPAY, razorpayPaymentId,
                    "Paid automatically via Razorpay AutoPay"));
        }
        createOwnerTransfer(order);
        notificationService.notifyUser(fee.getStudent().getUser() == null ? null
                        : fee.getStudent().getUser().getId(),
                "AutoPay successful", "INR " + capturedAmount + " was paid successfully.");
        AUDIT.info("action=autopay_captured paymentOrderId={} feeId={} amount={} razorpayPaymentId={}",
                order.getId(), fee.getId(), capturedAmount, razorpayPaymentId);
    }

    private void processCapturedOrder(PaymentOrder order, String razorpayPaymentId) {
        if (order.getStatus() == PaymentOrderStatus.PAID
                || order.getStatus() == PaymentOrderStatus.REFUND_PENDING
                || order.getStatus() == PaymentOrderStatus.REFUNDED) {
            return;
        }
        order.setRazorpayPaymentId(razorpayPaymentId);

        if (order.getPurpose() == PaymentPurpose.BOOKING) {
            try {
                Booking confirmed = bookingService.confirmAfterCapturedPayment(order.getBooking().getId());
                depositService.recordCollected(confirmed);
            } catch (ConflictException e) {
                refundStaleBookingPayment(order, e.getMessage());
                return;
            }
        } else {
            // The order was priced when it was created; the owner may have recorded a cash
            // payment against the same fee in between. Allocate only what is still
            // outstanding, exactly as recordAutoPayCaptured already does -- otherwise the
            // fee is booked as over-paid and the receipt overstates what it settled.
            Fee fee = order.getFee();
            BigDecimal outstanding = fee.getAmount().subtract(paymentRepository.sumPaidForFee(fee.getId()));
            BigDecimal allocated = order.getAmount().min(outstanding.max(BigDecimal.ZERO));
            if (allocated.compareTo(BigDecimal.ZERO) > 0) {
                feeService.recordSystemPayment(fee.getId(), new PaymentCreateRequest(
                        allocated, LocalDate.now(), PaymentMethod.RAZORPAY, razorpayPaymentId,
                        "Paid online via Razorpay (order " + order.getRazorpayOrderId() + ")"));
            }
            if (allocated.compareTo(order.getAmount()) < 0) {
                AUDIT.warn("action=payment_over_allocation paymentOrderId={} feeId={} captured={} allocated={}",
                        order.getId(), fee.getId(), order.getAmount(), allocated);
                notificationService.notifyUser(targetPg(order).getOwner().getId(), "Payment needs reconciliation",
                        "A student paid INR " + order.getAmount() + " online but only INR " + allocated
                                + " was outstanding. Reference: " + order.getId());
            }
            notificationService.notifyUser(fee.getStudent().getUser() == null ? null
                            : fee.getStudent().getUser().getId(),
                    "Payment received", "We received your rent payment of INR " + order.getAmount() + ".");
        }

        order.setStatus(PaymentOrderStatus.PAID);
        if (order.getPaidAt() == null) order.setPaidAt(Instant.now());
        order.setFailureReason(null);
        paymentOrderRepository.save(order);
        createOwnerTransfer(order);
        AUDIT.info("action=payment_captured paymentOrderId={} purpose={} amount={} razorpayPaymentId={}",
                order.getId(), order.getPurpose(), order.getAmount(), razorpayPaymentId);
    }

    @Transactional
    public boolean handleRefundWebhook(String event, com.fasterxml.jackson.databind.JsonNode root) {
        if (!event.startsWith("refund.")) return false;
        com.fasterxml.jackson.databind.JsonNode refund = root.path("payload").path("refund").path("entity");
        String paymentId = refund.path("payment_id").asText(null);
        if (paymentId == null) return false;
        PaymentOrder order = paymentOrderRepository.findByRazorpayPaymentIdForUpdate(paymentId)
                .orElse(null);
        if (order == null || order.getRazorpayRefundId() == null) return false;
        if ("refund.processed".equals(event)) {
            order.setStatus(PaymentOrderStatus.REFUNDED);
        } else if ("refund.failed".equals(event)) {
            order.setStatus(PaymentOrderStatus.FAILED);
            order.setFailureReason("Automatic refund failed; manual reconciliation required");
            notificationService.notifyUser(targetPg(order).getOwner().getId(), "Urgent payment reconciliation",
                    "An automatic customer refund failed. Payment order: " + order.getId());
        }
        paymentOrderRepository.save(order);
        return true;
    }

    private void refundStaleBookingPayment(PaymentOrder order, String reason) {
        RazorpayRefundResult refund = razorpayGateway.refund(order.getRazorpayPaymentId(), order.getAmount(),
                "expired-booking-" + order.getId());
        order.setRazorpayRefundId(refund.refundId());
        order.setStatus("processed".equalsIgnoreCase(refund.status())
                ? PaymentOrderStatus.REFUNDED : PaymentOrderStatus.REFUND_PENDING);
        order.setFailureReason("Booking could not be confirmed; full refund initiated: " + reason);
        paymentOrderRepository.save(order);
        UUID customerId = order.getBooking().getStudent().getUser() == null ? null
                : order.getBooking().getStudent().getUser().getId();
        notificationService.notifyUser(customerId, "Booking payment refunded",
                "The bed hold was no longer available, so a full refund of INR " + order.getAmount()
                        + " was initiated automatically.");
        notificationService.notifyUser(order.getBooking().getPg().getOwner().getId(), "Booking payment refunded",
                "A late payment for booking " + order.getBooking().getId() + " was refunded automatically.");
    }

    /**
     * Capturing the customer payment must stay successful even when Route is temporarily unavailable.
     * A FAILED transfer remains visible for operational retry/reconciliation.
     */
    private void createOwnerTransfer(PaymentOrder order) {
        Pg pg = targetPg(order);
        BigDecimal ownerAmount = order.getAmount()
                .multiply(BigDecimal.valueOf(10_000L - pg.getPlatformCommissionBps()))
                .divide(BigDecimal.valueOf(10_000), 2, RoundingMode.DOWN);
        order.setOwnerAmount(ownerAmount);
        if (ownerAmount.compareTo(BigDecimal.ZERO) <= 0) {
            // A 100% commission configuration has no owner portion to transfer.
            order.setTransferStatus(TransferStatus.NOT_CREATED);
            paymentOrderRepository.save(order);
            return;
        }

        boolean onHold = order.getPurpose() == PaymentPurpose.BOOKING;
        Long releaseAt = null;
        if (onHold) {
            releaseAt = order.getBooking().getMoveInDate().plusDays(1)
                    .atStartOfDay(ZoneOffset.UTC).toEpochSecond();
        }
        try {
            RazorpayTransferResult transfer = razorpayGateway.createTransfer(
                    order.getRazorpayPaymentId(), pg.getRazorpayLinkedAccountId(), ownerAmount,
                    onHold, releaseAt, "payment-order-" + order.getId());
            order.setRazorpayTransferId(transfer.transferId());
            order.setTransferStatus(transfer.onHold() ? TransferStatus.ON_HOLD : mapTransferStatus(transfer.status()));
        } catch (Exception e) {
            order.setTransferStatus(TransferStatus.FAILED);
            log.error("Razorpay Route transfer failed for payment order {}", order.getId(), e);
            notificationService.notifyUser(pg.getOwner().getId(), "Settlement needs attention",
                    "Customer payment was received, but settlement could not be created. Reference: " + order.getId());
        }
        paymentOrderRepository.save(order);
    }

    private TransferStatus mapTransferStatus(String status) {
        if (status == null) return TransferStatus.PENDING;
        return switch (status.toLowerCase()) {
            case "processed" -> TransferStatus.PROCESSED;
            case "reversed" -> TransferStatus.REVERSED;
            case "failed" -> TransferStatus.FAILED;
            default -> TransferStatus.PENDING;
        };
    }

    private PaymentOrder findOwnedExisting(String idempotencyKey, UUID userId, UUID studentId) {
        PaymentOrder existing = paymentOrderRepository.findByIdempotencyKeyAndDeletedAtIsNull(idempotencyKey)
                .orElse(null);
        if (existing == null) return null;
        if (userId != null) requireOwnedByUser(existing, userId);
        if (studentId != null && (existing.getFee() == null
                || !existing.getFee().getStudent().getId().equals(studentId))) {
            throw new ForbiddenException("This payment order does not belong to you");
        }
        return existing;
    }

    private void requireOwnedByUser(PaymentOrder order, UUID userId) {
        UUID ownerUserId = order.getBooking() != null
                ? order.getBooking().getStudent().getUser().getId()
                : order.getFee().getStudent().getUser().getId();
        if (!ownerUserId.equals(userId)) {
            throw new ForbiddenException("This payment order does not belong to you");
        }
    }

    private void requirePaymentsEnabled(Pg pg) {
        if (!razorpayProperties.isConfigured()) {
            throw new UnsupportedOperationException("Razorpay API credentials are not configured");
        }
        if (pg.getPaymentOnboardingStatus() != PaymentOnboardingStatus.VERIFIED
                || pg.getRazorpayLinkedAccountId() == null || pg.getRazorpayLinkedAccountId().isBlank()) {
            throw new ConflictException("Online payments are not enabled for this PG yet");
        }
    }

    private PaymentOrder baseOrder(String idempotencyKey, BigDecimal amount, String razorpayOrderId) {
        PaymentOrder order = new PaymentOrder();
        order.setIdempotencyKey(idempotencyKey);
        order.setAmount(amount);
        order.setCurrency("INR");
        order.setStatus(PaymentOrderStatus.CREATED);
        order.setRazorpayOrderId(razorpayOrderId);
        return order;
    }

    private Pg targetPg(PaymentOrder order) {
        return order.getBooking() != null ? order.getBooking().getPg() : order.getFee().getPg();
    }

    private PaymentOrderResponse response(PaymentOrder order) {
        return PaymentOrderResponse.from(order, razorpayProperties.getKeyId());
    }

    private void notifyPaymentFailure(PaymentOrder order) {
        Pg pg = targetPg(order);
        UUID customerId = order.getBooking() != null
                ? order.getBooking().getStudent().getUser().getId()
                : order.getFee().getStudent().getUser().getId();
        notificationService.notifyUser(customerId, "Payment failed",
                "Your payment was not captured. You can retry from the app.");
        notificationService.notifyUser(pg.getOwner().getId(), "Customer payment failed",
                "A payment attempt for INR " + order.getAmount() + " was not captured.");
    }
}
