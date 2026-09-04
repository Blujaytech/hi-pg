package com.pgplatform.billing.dto;

import com.pgplatform.billing.PaymentMethod;
import com.pgplatform.billing.Receipt;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record ReceiptResponse(
        UUID id,
        String receiptNumber,
        UUID paymentId,
        UUID studentId,
        String studentName,
        UUID pgId,
        String pgName,
        Integer feePeriodMonth,
        Integer feePeriodYear,
        BigDecimal amount,
        LocalDate paidOn,
        PaymentMethod method
) {
    public static ReceiptResponse from(Receipt receipt) {
        return new ReceiptResponse(
                receipt.getId(),
                receipt.getReceiptNumber(),
                receipt.getPayment().getId(),
                receipt.getStudent().getId(),
                receipt.getStudentNameSnapshot(),
                receipt.getPg().getId(),
                receipt.getPgNameSnapshot(),
                receipt.getFeePeriodMonth(),
                receipt.getFeePeriodYear(),
                receipt.getAmount(),
                receipt.getPaidOn(),
                receipt.getMethod()
        );
    }
}
