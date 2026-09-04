package com.pgplatform.billing;

import com.pgplatform.billing.dto.FeeCreateRequest;
import com.pgplatform.billing.dto.FeeResponse;
import com.pgplatform.billing.dto.PaymentCreateRequest;
import com.pgplatform.billing.dto.PaymentResponse;
import com.pgplatform.common.ConflictException;
import com.pgplatform.common.ForbiddenException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.owner.PgService;
import com.pgplatform.student.Student;
import com.pgplatform.student.StudentService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

@Service
public class FeeService {

    private final FeeRepository feeRepository;
    private final PaymentRepository paymentRepository;
    private final StudentService studentService;
    private final PgService pgService;
    private final ReceiptService receiptService;

    public FeeService(FeeRepository feeRepository, PaymentRepository paymentRepository,
                       StudentService studentService, PgService pgService, ReceiptService receiptService) {
        this.feeRepository = feeRepository;
        this.paymentRepository = paymentRepository;
        this.studentService = studentService;
        this.pgService = pgService;
        this.receiptService = receiptService;
    }

    @Transactional
    public FeeResponse create(UUID studentId, UUID ownerId, FeeCreateRequest request) {
        Student student = studentService.requireOwnedStudent(studentId, ownerId);

        if (feeRepository.existsByStudentIdAndPeriodYearAndPeriodMonthAndDeletedAtIsNull(
                studentId, request.periodYear(), request.periodMonth())) {
            throw new ConflictException("A fee for this student and period already exists");
        }

        Fee fee = new Fee();
        fee.setStudent(student);
        fee.setPg(student.getPg());
        fee.setPeriodMonth(request.periodMonth());
        fee.setPeriodYear(request.periodYear());
        fee.setAmount(request.amount());
        fee.setDueDate(request.dueDate());
        fee.setNotes(request.notes());
        fee.setStatus(FeeStatus.PENDING);

        return toResponse(feeRepository.save(fee));
    }

    @Transactional(readOnly = true)
    public List<FeeResponse> listForStudent(UUID studentId, UUID ownerId) {
        studentService.requireOwnedStudent(studentId, ownerId);
        return feeRepository.findAllByStudentIdAndDeletedAtIsNullOrderByPeriodYearDescPeriodMonthDesc(studentId)
                .stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public List<FeeResponse> listForPg(UUID pgId, UUID ownerId) {
        pgService.requireOwnedPg(pgId, ownerId);
        return feeRepository.findAllByPgIdAndDeletedAtIsNullOrderByDueDateDesc(pgId)
                .stream().map(this::toResponse).toList();
    }

    @Transactional(readOnly = true)
    public FeeResponse get(UUID feeId, UUID ownerId) {
        return toResponse(requireOwnedFee(feeId, ownerId));
    }

    @Transactional
    public FeeResponse recordPayment(UUID feeId, UUID ownerId, PaymentCreateRequest request) {
        Fee fee = requireOwnedFee(feeId, ownerId);
        return recordPaymentInternal(fee, request);
    }

    /**
     * For payment paths that already validated the Fee some other way and
     * have no ownerId in context -- today, only the Razorpay webhook
     * (PaymentOrderService), which validates via the PaymentOrder's own fee
     * link instead of owner identity. Not exposed through any controller
     * directly.
     */
    @Transactional
    public FeeResponse recordSystemPayment(UUID feeId, PaymentCreateRequest request) {
        Fee fee = feeRepository.findByIdAndDeletedAtIsNull(feeId)
                .orElseThrow(() -> new NotFoundException("Fee not found"));
        return recordPaymentInternal(fee, request);
    }

    /** Self-service: a logged-in Student viewing their own fees, not scoped by owner (see StudentFeeController). */
    @Transactional(readOnly = true)
    public List<FeeResponse> listForStudentSelfService(UUID studentId) {
        return feeRepository.findAllByStudentIdAndDeletedAtIsNullOrderByPeriodYearDescPeriodMonthDesc(studentId)
                .stream().map(this::toResponse).toList();
    }

    /** Self-service: fetches one fee for the calling student, checked against studentId rather than an owner. */
    @Transactional(readOnly = true)
    public FeeResponse getForStudentSelfService(UUID feeId, UUID studentId) {
        Fee fee = feeRepository.findByIdAndDeletedAtIsNull(feeId)
                .orElseThrow(() -> new NotFoundException("Fee not found"));
        if (!fee.getStudent().getId().equals(studentId)) {
            throw new ForbiddenException("This fee does not belong to you");
        }
        return toResponse(fee);
    }

    private FeeResponse recordPaymentInternal(Fee fee, PaymentCreateRequest request) {
        Payment payment = new Payment();
        payment.setFee(fee);
        payment.setAmountPaid(request.amountPaid());
        payment.setPaidOn(request.paidOn());
        payment.setMethod(request.method());
        payment.setReference(request.reference());
        payment.setNote(request.note());
        payment = paymentRepository.save(payment);
        receiptService.generateFor(payment);

        BigDecimal totalPaid = paymentRepository.sumPaidForFee(fee.getId());
        fee.setStatus(deriveStatus(fee.getAmount(), totalPaid));
        feeRepository.save(fee);

        return toResponse(fee);
    }

    @Transactional
    public void delete(UUID feeId, UUID ownerId) {
        Fee fee = requireOwnedFee(feeId, ownerId);
        fee.markDeleted();
        feeRepository.save(fee);
    }

    private FeeStatus deriveStatus(BigDecimal amount, BigDecimal totalPaid) {
        if (totalPaid.compareTo(BigDecimal.ZERO) <= 0) {
            return FeeStatus.PENDING;
        }
        if (totalPaid.compareTo(amount) >= 0) {
            return FeeStatus.PAID;
        }
        return FeeStatus.PARTIALLY_PAID;
    }

    private FeeResponse toResponse(Fee fee) {
        List<Payment> payments = paymentRepository.findAllByFeeIdAndDeletedAtIsNullOrderByPaidOnDesc(fee.getId());
        BigDecimal amountPaid = payments.stream().map(Payment::getAmountPaid).reduce(BigDecimal.ZERO, BigDecimal::add);
        List<PaymentResponse> paymentResponses = payments.stream().map(PaymentResponse::from).toList();
        return FeeResponse.from(fee, amountPaid, paymentResponses);
    }

    Fee requireOwnedFee(UUID feeId, UUID ownerId) {
        Fee fee = feeRepository.findByIdAndDeletedAtIsNull(feeId)
                .orElseThrow(() -> new NotFoundException("Fee not found"));
        if (!fee.getPg().getOwner().getId().equals(ownerId)) {
            throw new ForbiddenException("You do not have access to this fee");
        }
        return fee;
    }
}
