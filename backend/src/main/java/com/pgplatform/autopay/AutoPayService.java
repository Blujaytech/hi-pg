package com.pgplatform.autopay;

import com.fasterxml.jackson.databind.JsonNode;
import com.pgplatform.autopay.dto.AutoPayCreateRequest;
import com.pgplatform.autopay.dto.AutoPayResponse;
import com.pgplatform.billing.Fee;
import com.pgplatform.billing.FeeRepository;
import com.pgplatform.billing.FeeStatus;
import com.pgplatform.common.ConflictException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.notification.NotificationService;
import com.pgplatform.owner.PaymentOnboardingStatus;
import com.pgplatform.payment.PaymentOrderService;
import com.pgplatform.payment.RazorpayGateway;
import com.pgplatform.payment.RazorpayProperties;
import com.pgplatform.payment.RazorpaySubscriptionResult;
import com.pgplatform.student.Student;
import com.pgplatform.student.StudentRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.Comparator;
import java.util.UUID;

@Service
public class AutoPayService {
    private static final ZoneId INDIA = ZoneId.of("Asia/Kolkata");

    private final AutoPayMandateRepository mandateRepository;
    private final StudentRepository studentRepository;
    private final FeeRepository feeRepository;
    private final RazorpayGateway razorpayGateway;
    private final RazorpayProperties razorpayProperties;
    private final PaymentOrderService paymentOrderService;
    private final NotificationService notificationService;

    public AutoPayService(AutoPayMandateRepository mandateRepository, StudentRepository studentRepository,
                          FeeRepository feeRepository, RazorpayGateway razorpayGateway,
                          RazorpayProperties razorpayProperties, PaymentOrderService paymentOrderService,
                          NotificationService notificationService) {
        this.mandateRepository = mandateRepository;
        this.studentRepository = studentRepository;
        this.feeRepository = feeRepository;
        this.razorpayGateway = razorpayGateway;
        this.razorpayProperties = razorpayProperties;
        this.paymentOrderService = paymentOrderService;
        this.notificationService = notificationService;
    }

    @Transactional
    public AutoPayResponse create(UUID userId, AutoPayCreateRequest request) {
        Student student = studentRepository.findByUserIdAndDeletedAtIsNull(userId)
                .orElseThrow(() -> new NotFoundException("Student profile not found"));
        if (student.getBed() == null) {
            throw new ConflictException("AutoPay can be enabled after check-in and bed allocation");
        }
        if (mandateRepository.findByStudentIdAndDeletedAtIsNull(student.getId()).isPresent()) {
            throw new ConflictException("An AutoPay mandate already exists");
        }
        if (!razorpayProperties.isConfigured()) {
            throw new UnsupportedOperationException("Razorpay API credentials are not configured");
        }
        if (student.getPg().getPaymentOnboardingStatus() != PaymentOnboardingStatus.VERIFIED
                || student.getPg().getRazorpayLinkedAccountId() == null) {
            throw new ConflictException("Online payments are not enabled for this PG yet");
        }

        BigDecimal rent = student.getBed().getRoom().getRentPerBed();
        LocalDate firstCharge = nextChargeDate(request.dueDay());
        long startsAt = firstCharge.atStartOfDay(INDIA).toEpochSecond();
        RazorpaySubscriptionResult result = razorpayGateway.createMonthlySubscription(
                rent, "Monthly rent - " + student.getPg().getName(), startsAt, 120);

        AutoPayMandate mandate = new AutoPayMandate();
        mandate.setStudent(student);
        mandate.setPg(student.getPg());
        mandate.setAmount(rent);
        mandate.setDueDay(request.dueDay());
        mandate.setNextChargeDate(firstCharge);
        mandate.setStatus(AutoPayStatus.PENDING_AUTHORIZATION);
        mandate.setRazorpayPlanId(result.planId());
        mandate.setRazorpaySubscriptionId(result.subscriptionId());
        mandate = mandateRepository.save(mandate);
        return AutoPayResponse.from(mandate, result.shortUrl(), razorpayProperties.getKeyId());
    }

    @Transactional(readOnly = true)
    public AutoPayResponse get(UUID userId) {
        Student student = studentRepository.findByUserIdAndDeletedAtIsNull(userId)
                .orElseThrow(() -> new NotFoundException("Student profile not found"));
        AutoPayMandate mandate = mandateRepository.findByStudentIdAndDeletedAtIsNull(student.getId())
                .orElseThrow(() -> new NotFoundException("AutoPay mandate not found"));
        return AutoPayResponse.from(mandate, null, razorpayProperties.getKeyId());
    }

    /** Returns true when the webhook belongs to a known subscription. */
    @Transactional
    public boolean handleWebhook(String event, JsonNode root) {
        String subscriptionId = text(root.path("payload").path("subscription").path("entity"), "id");
        JsonNode payment = root.path("payload").path("payment").path("entity");
        if (subscriptionId == null) subscriptionId = text(payment, "subscription_id");
        if (subscriptionId == null) return false;

        AutoPayMandate mandate = mandateRepository.findByRazorpaySubscriptionIdAndDeletedAtIsNull(subscriptionId)
                .orElse(null);
        if (mandate == null) return false;

        switch (event) {
            case "subscription.activated", "subscription.charged" -> {
                mandate.setStatus(AutoPayStatus.ACTIVE);
                mandate.setFailureReason(null);
            }
            case "subscription.paused" -> mandate.setStatus(AutoPayStatus.PAUSED);
            case "subscription.halted" -> mandate.setStatus(AutoPayStatus.HALTED);
            case "subscription.cancelled", "subscription.completed" -> mandate.setStatus(AutoPayStatus.CANCELLED);
            case "payment.failed" -> {
                mandate.setStatus(AutoPayStatus.FAILED);
                mandate.setFailureReason(text(payment, "error_description") == null
                        ? "Recurring payment failed" : text(payment, "error_description"));
                notifyFailure(mandate);
            }
            case "payment.captured" -> recordCapturedCharge(mandate, payment);
            default -> { return true; }
        }
        mandateRepository.save(mandate);
        return true;
    }

    private void recordCapturedCharge(AutoPayMandate mandate, JsonNode payment) {
        String paymentId = text(payment, "id");
        if (paymentId == null) return;
        BigDecimal amount = BigDecimal.valueOf(payment.path("amount").asLong()).movePointLeft(2);
        Fee fee = feeRepository.findAllByStudentIdAndDeletedAtIsNullOrderByPeriodYearDescPeriodMonthDesc(
                        mandate.getStudent().getId()).stream()
                .filter(candidate -> candidate.getStatus() != FeeStatus.PAID)
                .min(Comparator.comparing(Fee::effectiveDueDate))
                .orElse(null);
        if (fee == null) {
            notificationService.notifyUser(mandate.getPg().getOwner().getId(), "Unallocated AutoPay received",
                    "A recurring payment was captured but no unpaid fee exists. Payment: " + paymentId);
            return;
        }
        paymentOrderService.recordAutoPayCaptured(fee, paymentId, text(payment, "order_id"), amount);
        mandate.setStatus(AutoPayStatus.ACTIVE);
        mandate.setFailureReason(null);
        mandate.setNextChargeDate(nextMonth(mandate.getNextChargeDate(), mandate.getDueDay()));
    }

    private void notifyFailure(AutoPayMandate mandate) {
        UUID studentUserId = mandate.getStudent().getUser() == null ? null : mandate.getStudent().getUser().getId();
        notificationService.notifyUser(studentUserId, "AutoPay failed",
                "Your rent AutoPay could not be debited. Contact your owner if you need more time.");
        notificationService.notifyUser(mandate.getPg().getOwner().getId(), "Student AutoPay failed",
                mandate.getStudent().getFullName() + "'s rent AutoPay failed. You can extend their due date.");
    }

    private LocalDate nextChargeDate(int dueDay) {
        LocalDate today = LocalDate.now(INDIA);
        LocalDate thisMonth = today.withDayOfMonth(dueDay);
        return thisMonth.isAfter(today) ? thisMonth : thisMonth.plusMonths(1);
    }

    private LocalDate nextMonth(LocalDate current, int dueDay) {
        LocalDate basis = current == null ? LocalDate.now(INDIA) : current;
        return basis.plusMonths(1).withDayOfMonth(dueDay);
    }

    private String text(JsonNode node, String field) {
        String value = node.path(field).asText(null);
        return value == null || value.isBlank() ? null : value;
    }
}
