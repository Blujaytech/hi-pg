package com.pgplatform.billing.dto;

import com.pgplatform.billing.Fee;
import com.pgplatform.billing.FeeStatus;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record FeeResponse(
        UUID id,
        UUID studentId,
        String studentName,
        UUID pgId,
        Integer periodMonth,
        Integer periodYear,
        BigDecimal amount,
        BigDecimal amountPaid,
        BigDecimal balance,
        LocalDate dueDate,
        FeeStatus status,
        boolean overdue,
        String notes,
        List<PaymentResponse> payments
) {
    public static FeeResponse from(Fee fee, BigDecimal amountPaid, List<PaymentResponse> payments) {
        BigDecimal balance = fee.getAmount().subtract(amountPaid);
        boolean overdue = fee.getStatus() != FeeStatus.PAID && fee.getDueDate().isBefore(LocalDate.now());
        return new FeeResponse(
                fee.getId(), fee.getStudent().getId(), fee.getStudent().getFullName(), fee.getPg().getId(),
                fee.getPeriodMonth(), fee.getPeriodYear(), fee.getAmount(), amountPaid, balance,
                fee.getDueDate(), fee.getStatus(), overdue, fee.getNotes(), payments
        );
    }
}
