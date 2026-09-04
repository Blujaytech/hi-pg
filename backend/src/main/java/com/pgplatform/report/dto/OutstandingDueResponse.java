package com.pgplatform.report.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record OutstandingDueResponse(
        UUID feeId,
        UUID studentId,
        String studentName,
        UUID pgId,
        String pgName,
        int periodMonth,
        int periodYear,
        BigDecimal amount,
        BigDecimal amountPaid,
        BigDecimal balance,
        LocalDate dueDate,
        boolean overdue
) {
}
