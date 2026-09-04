package com.pgplatform.expense.dto;

import com.pgplatform.expense.Expense;
import com.pgplatform.expense.ExpenseCategory;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public record ExpenseResponse(
        UUID id,
        UUID pgId,
        ExpenseCategory category,
        String description,
        BigDecimal amount,
        LocalDate expenseDate
) {
    public static ExpenseResponse from(Expense expense) {
        return new ExpenseResponse(expense.getId(), expense.getPg().getId(), expense.getCategory(),
                expense.getDescription(), expense.getAmount(), expense.getExpenseDate());
    }
}
