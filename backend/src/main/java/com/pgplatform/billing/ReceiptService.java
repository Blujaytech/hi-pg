package com.pgplatform.billing;

import com.pgplatform.common.ForbiddenException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.billing.dto.ReceiptResponse;
import com.pgplatform.owner.PgService;
import com.pgplatform.student.StudentService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Service
public class ReceiptService {

    private final ReceiptRepository receiptRepository;
    private final StudentService studentService;
    private final PgService pgService;

    public ReceiptService(ReceiptRepository receiptRepository, StudentService studentService, PgService pgService) {
        this.receiptRepository = receiptRepository;
        this.studentService = studentService;
        this.pgService = pgService;
    }

    /** Called only from FeeService.recordPayment, right after a Payment is saved. Never exposed as its own "create" endpoint -- a receipt without a payment behind it shouldn't be possible. */
    @Transactional
    Receipt generateFor(Payment payment) {
        Fee fee = payment.getFee();

        Receipt receipt = new Receipt();
        receipt.setReceiptNumber(nextReceiptNumber());
        receipt.setPayment(payment);
        receipt.setStudent(fee.getStudent());
        receipt.setPg(fee.getPg());
        receipt.setStudentNameSnapshot(fee.getStudent().getFullName());
        receipt.setPgNameSnapshot(fee.getPg().getName());
        receipt.setFeePeriodMonth(fee.getPeriodMonth());
        receipt.setFeePeriodYear(fee.getPeriodYear());
        receipt.setAmount(payment.getAmountPaid());
        receipt.setPaidOn(payment.getPaidOn());
        receipt.setMethod(payment.getMethod());

        return receiptRepository.save(receipt);
    }

    @Transactional(readOnly = true)
    public List<ReceiptResponse> listForStudent(UUID studentId, UUID ownerId) {
        studentService.requireOwnedStudent(studentId, ownerId);
        return receiptRepository.findAllByStudentIdAndDeletedAtIsNullOrderByPaidOnDesc(studentId)
                .stream().map(ReceiptResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public List<ReceiptResponse> listForPg(UUID pgId, UUID ownerId) {
        pgService.requireOwnedPg(pgId, ownerId);
        return receiptRepository.findAllByPgIdAndDeletedAtIsNullOrderByPaidOnDesc(pgId)
                .stream().map(ReceiptResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public ReceiptResponse get(UUID receiptId, UUID ownerId) {
        Receipt receipt = receiptRepository.findByIdAndDeletedAtIsNull(receiptId)
                .orElseThrow(() -> new NotFoundException("Receipt not found"));
        if (!receipt.getPg().getOwner().getId().equals(ownerId)) {
            throw new ForbiddenException("You do not have access to this receipt");
        }
        return ReceiptResponse.from(receipt);
    }

    private String nextReceiptNumber() {
        long seq = receiptRepository.nextSequenceValue();
        return "RCPT-" + LocalDate.now().getYear() + "-" + String.format("%06d", seq);
    }
}
