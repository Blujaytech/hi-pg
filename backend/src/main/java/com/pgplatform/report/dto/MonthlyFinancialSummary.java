package com.pgplatform.report.dto;

import java.math.BigDecimal;

/**
 * One calendar month's collected-vs-spent numbers. Computed on every
 * request from Fee/Payment/Expense rows -- nothing is stored or
 * pre-aggregated, so this is always correct as of "now" but re-derives the
 * sums each call (see docs/decisions.md for why that tradeoff is fine at
 * today's scale).
 */
public record MonthlyFinancialSummary(
        int year,
        int month,
        BigDecimal collected,
        BigDecimal expenses,
        BigDecimal net
) {
    public static MonthlyFinancialSummary of(int year, int month, BigDecimal collected, BigDecimal expenses) {
        return new MonthlyFinancialSummary(year, month, collected, expenses, collected.subtract(expenses));
    }
}
