package com.pgplatform.deposit;

import com.fasterxml.jackson.databind.JsonNode;
import com.pgplatform.booking.Booking;
import com.pgplatform.booking.BookingService;
import com.pgplatform.common.ConflictException;
import com.pgplatform.common.ForbiddenException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.deposit.dto.DepositAdjustmentRequest;
import com.pgplatform.deposit.dto.DepositLedgerResponse;
import com.pgplatform.notification.NotificationService;
import com.pgplatform.payment.PaymentOrder;
import com.pgplatform.payment.PaymentOrderRepository;
import com.pgplatform.payment.PaymentOrderStatus;
import com.pgplatform.payment.RazorpayGateway;
import com.pgplatform.payment.RazorpayRefundResult;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@Service
public class DepositService {
    private final DepositTransactionRepository transactionRepository;
    private final BookingService bookingService;
    private final PaymentOrderRepository paymentOrderRepository;
    private final RazorpayGateway razorpayGateway;
    private final NotificationService notificationService;

    public DepositService(DepositTransactionRepository transactionRepository, BookingService bookingService,
                          PaymentOrderRepository paymentOrderRepository, RazorpayGateway razorpayGateway,
                          NotificationService notificationService) {
        this.transactionRepository = transactionRepository;
        this.bookingService = bookingService;
        this.paymentOrderRepository = paymentOrderRepository;
        this.razorpayGateway = razorpayGateway;
        this.notificationService = notificationService;
    }

    @Transactional
    public void recordCollected(Booking booking) {
        if (booking.getSecurityDepositAmount().compareTo(BigDecimal.ZERO) <= 0
                || transactionRepository.existsByBookingIdAndTypeAndDeletedAtIsNull(
                booking.getId(), DepositTransactionType.COLLECTED)) {
            return;
        }
        DepositTransaction transaction = base(booking, DepositTransactionType.COLLECTED,
                booking.getSecurityDepositAmount(), "Security deposit collected with booking payment");
        transactionRepository.save(transaction);
    }

    @Transactional
    public DepositLedgerResponse deduct(UUID bookingId, UUID ownerId, DepositAdjustmentRequest request) {
        Booking booking = requireOwnerForUpdate(bookingId, ownerId);
        requireAvailable(bookingId, request.amount());
        transactionRepository.save(base(booking, DepositTransactionType.DEDUCTION,
                request.amount(), request.reason()));
        notifyStudent(booking, "Deposit deduction recorded",
                "INR " + request.amount() + " was deducted from your deposit: " + request.reason());
        return ledger(bookingId);
    }

    @Transactional
    public DepositLedgerResponse refund(UUID bookingId, UUID ownerId, DepositAdjustmentRequest request) {
        Booking booking = requireOwnerForUpdate(bookingId, ownerId);
        requireAvailable(bookingId, request.amount());
        PaymentOrder paymentOrder = paymentOrderRepository
                .findFirstByBookingIdAndStatusAndDeletedAtIsNullOrderByCreatedAtDesc(bookingId, PaymentOrderStatus.PAID)
                .orElseThrow(() -> new ConflictException("No captured booking payment is available to refund"));

        DepositTransaction transaction = base(booking, DepositTransactionType.REFUND,
                request.amount(), request.reason());
        transaction.setStatus(DepositTransactionStatus.PENDING);
        transaction = transactionRepository.save(transaction);
        try {
            RazorpayRefundResult refund = razorpayGateway.refund(paymentOrder.getRazorpayPaymentId(),
                    request.amount(), "deposit-" + transaction.getId());
            transaction.setRazorpayRefundId(refund.refundId());
            transaction.setStatus("processed".equalsIgnoreCase(refund.status())
                    ? DepositTransactionStatus.COMPLETED : DepositTransactionStatus.PENDING);
            transactionRepository.save(transaction);
            notifyStudent(booking, "Deposit refund initiated",
                    "Your owner initiated a deposit refund of INR " + request.amount() + ".");
        } catch (Exception e) {
            transaction.setStatus(DepositTransactionStatus.FAILED);
            transactionRepository.save(transaction);
            throw e;
        }
        return ledger(bookingId);
    }

    @Transactional(readOnly = true)
    public DepositLedgerResponse ownerLedger(UUID bookingId, UUID ownerId) {
        requireOwner(bookingId, ownerId);
        return ledger(bookingId);
    }

    @Transactional(readOnly = true)
    public DepositLedgerResponse studentLedger(UUID bookingId, UUID userId) {
        Booking booking = bookingService.requireBooking(bookingId);
        if (booking.getStudent().getUser() == null || !booking.getStudent().getUser().getId().equals(userId)) {
            throw new ForbiddenException("This booking does not belong to you");
        }
        return ledger(bookingId);
    }

    @Transactional
    public boolean handleWebhook(String event, JsonNode root) {
        if (!event.startsWith("refund.")) return false;
        JsonNode refund = root.path("payload").path("refund").path("entity");
        String refundId = refund.path("id").asText(null);
        if (refundId == null) return false;
        DepositTransaction transaction = transactionRepository.findByRazorpayRefundIdAndDeletedAtIsNull(refundId)
                .orElse(null);
        if (transaction == null) return false;
        transaction.setStatus(switch (event) {
            case "refund.processed" -> DepositTransactionStatus.COMPLETED;
            case "refund.failed" -> DepositTransactionStatus.FAILED;
            default -> DepositTransactionStatus.PENDING;
        });
        transactionRepository.save(transaction);
        return true;
    }

    private DepositLedgerResponse ledger(UUID bookingId) {
        List<DepositTransaction> entries = transactionRepository
                .findAllByBookingIdAndDeletedAtIsNullOrderByCreatedAtAsc(bookingId);
        BigDecimal collected = sum(entries, DepositTransactionType.COLLECTED, DepositTransactionStatus.COMPLETED);
        BigDecimal deducted = sum(entries, DepositTransactionType.DEDUCTION, DepositTransactionStatus.COMPLETED);
        BigDecimal refunded = entries.stream()
                .filter(e -> e.getType() == DepositTransactionType.REFUND
                        && e.getStatus() != DepositTransactionStatus.FAILED)
                .map(DepositTransaction::getAmount).reduce(BigDecimal.ZERO, BigDecimal::add);
        return new DepositLedgerResponse(bookingId, collected, deducted, refunded,
                collected.subtract(deducted).subtract(refunded),
                entries.stream().map(DepositLedgerResponse.Entry::from).toList());
    }

    private BigDecimal sum(List<DepositTransaction> entries, DepositTransactionType type,
                           DepositTransactionStatus status) {
        return entries.stream().filter(e -> e.getType() == type && e.getStatus() == status)
                .map(DepositTransaction::getAmount).reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private void requireAvailable(UUID bookingId, BigDecimal amount) {
        if (ledger(bookingId).availableBalance().compareTo(amount) < 0) {
            throw new ConflictException("The amount exceeds the available deposit balance");
        }
    }

    private Booking requireOwner(UUID bookingId, UUID ownerId) {
        return checkOwner(bookingService.requireBooking(bookingId), ownerId);
    }

    /**
     * Deduction and refund both decide against a balance summed over ledger rows, so
     * two concurrent adjustments could each see the full balance and both be allowed --
     * paying out more than was ever collected. Locking the booking row first serializes
     * them, so the second reads a balance that already includes the first.
     */
    private Booking requireOwnerForUpdate(UUID bookingId, UUID ownerId) {
        return checkOwner(bookingService.requireBookingForUpdate(bookingId), ownerId);
    }

    private Booking checkOwner(Booking booking, UUID ownerId) {
        if (!booking.getPg().getOwner().getId().equals(ownerId)) {
            throw new ForbiddenException("You do not have access to this booking");
        }
        return booking;
    }

    private DepositTransaction base(Booking booking, DepositTransactionType type,
                                    BigDecimal amount, String reason) {
        DepositTransaction transaction = new DepositTransaction();
        transaction.setBooking(booking);
        transaction.setType(type);
        transaction.setAmount(amount);
        transaction.setReason(reason);
        transaction.setStatus(DepositTransactionStatus.COMPLETED);
        return transaction;
    }

    private void notifyStudent(Booking booking, String title, String message) {
        notificationService.notifyUser(booking.getStudent().getUser() == null ? null
                : booking.getStudent().getUser().getId(), title, message);
    }
}
