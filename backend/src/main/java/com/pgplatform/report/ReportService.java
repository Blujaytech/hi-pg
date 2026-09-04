package com.pgplatform.report;

import com.pgplatform.billing.Fee;
import com.pgplatform.billing.FeeRepository;
import com.pgplatform.billing.FeeStatus;
import com.pgplatform.billing.PaymentRepository;
import com.pgplatform.expense.ExpenseRepository;
import com.pgplatform.owner.BedRepository;
import com.pgplatform.owner.BedStatus;
import com.pgplatform.owner.Pg;
import com.pgplatform.owner.PgRepository;
import com.pgplatform.owner.PgService;
import com.pgplatform.report.dto.MonthlyFinancialSummary;
import com.pgplatform.report.dto.OccupancyReportResponse;
import com.pgplatform.report.dto.OutstandingDueResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;

/**
 * All reports here are computed at read time from Fee/Payment/Expense/Bed
 * rows -- nothing is pre-aggregated into a reporting table. That is a
 * deliberate choice for this stage of the project; see docs/decisions.md
 * for why and when to revisit it (materialized/scheduled aggregates once a
 * PG's history is large enough that this becomes slow).
 */
@Service
public class ReportService {

    private static final int MAX_MONTHS = 24;

    private final FeeRepository feeRepository;
    private final ExpenseRepository expenseRepository;
    private final PaymentRepository paymentRepository;
    private final BedRepository bedRepository;
    private final PgRepository pgRepository;
    private final PgService pgService;

    public ReportService(FeeRepository feeRepository, ExpenseRepository expenseRepository,
                          PaymentRepository paymentRepository, BedRepository bedRepository,
                          PgRepository pgRepository, PgService pgService) {
        this.feeRepository = feeRepository;
        this.expenseRepository = expenseRepository;
        this.paymentRepository = paymentRepository;
        this.bedRepository = bedRepository;
        this.pgRepository = pgRepository;
        this.pgService = pgService;
    }

    @Transactional(readOnly = true)
    public List<MonthlyFinancialSummary> revenueForOwner(UUID ownerId, int months) {
        return buildRevenueSeries(months,
                (from, to) -> feeRepository.sumCollectedByOwnerIdBetween(ownerId, from, to),
                (from, to) -> expenseRepository.sumByOwnerIdBetween(ownerId, from, to));
    }

    @Transactional(readOnly = true)
    public List<MonthlyFinancialSummary> revenueForPg(UUID pgId, UUID ownerId, int months) {
        pgService.requireOwnedPg(pgId, ownerId);
        return buildRevenueSeries(months,
                (from, to) -> feeRepository.sumCollectedByPgIdBetween(pgId, from, to),
                (from, to) -> expenseRepository.sumByPgIdBetween(pgId, from, to));
    }

    private interface RangeSum {
        java.math.BigDecimal sum(LocalDate from, LocalDate to);
    }

    private List<MonthlyFinancialSummary> buildRevenueSeries(int months, RangeSum collected, RangeSum expenses) {
        int clamped = Math.max(1, Math.min(months, MAX_MONTHS));
        List<MonthlyFinancialSummary> result = new ArrayList<>();
        YearMonth cursor = YearMonth.now().minusMonths(clamped - 1L);
        for (int i = 0; i < clamped; i++) {
            LocalDate from = cursor.atDay(1);
            LocalDate to = cursor.atEndOfMonth();
            result.add(MonthlyFinancialSummary.of(cursor.getYear(), cursor.getMonthValue(),
                    collected.sum(from, to), expenses.sum(from, to)));
            cursor = cursor.plusMonths(1);
        }
        return result;
    }

    @Transactional(readOnly = true)
    public List<OccupancyReportResponse> occupancyForOwner(UUID ownerId) {
        List<Pg> pgs = pgRepository.findAllByOwnerIdAndDeletedAtIsNullOrderByCreatedAtDesc(ownerId);
        List<OccupancyReportResponse> result = new ArrayList<>();
        for (Pg pg : pgs) {
            result.add(occupancyForOnePg(pg));
        }
        return result;
    }

    @Transactional(readOnly = true)
    public OccupancyReportResponse occupancyForPg(UUID pgId, UUID ownerId) {
        Pg pg = pgService.requireOwnedPg(pgId, ownerId);
        return occupancyForOnePg(pg);
    }

    private OccupancyReportResponse occupancyForOnePg(Pg pg) {
        long occupied = bedRepository.countByPgIdAndStatus(pg.getId(), BedStatus.OCCUPIED);
        long available = bedRepository.countByPgIdAndStatus(pg.getId(), BedStatus.AVAILABLE);
        long maintenance = bedRepository.countByPgIdAndStatus(pg.getId(), BedStatus.MAINTENANCE);
        return OccupancyReportResponse.of(pg.getId(), pg.getName(), occupied, available, maintenance);
    }

    @Transactional(readOnly = true)
    public List<OutstandingDueResponse> outstandingDuesForOwner(UUID ownerId) {
        List<Fee> fees = feeRepository.findAllByPgOwnerIdAndStatusNotAndDeletedAtIsNullOrderByDueDateAsc(ownerId, FeeStatus.PAID);
        return toOutstandingDues(fees);
    }

    @Transactional(readOnly = true)
    public List<OutstandingDueResponse> outstandingDuesForPg(UUID pgId, UUID ownerId) {
        pgService.requireOwnedPg(pgId, ownerId);
        List<Fee> fees = feeRepository.findAllByPgIdAndStatusNotAndDeletedAtIsNullOrderByDueDateAsc(pgId, FeeStatus.PAID);
        return toOutstandingDues(fees);
    }

    private List<OutstandingDueResponse> toOutstandingDues(List<Fee> fees) {
        LocalDate today = LocalDate.now();
        List<OutstandingDueResponse> result = new ArrayList<>();
        for (Fee fee : fees) {
            java.math.BigDecimal paid = paymentRepository.sumPaidForFee(fee.getId());
            java.math.BigDecimal balance = fee.getAmount().subtract(paid);
            result.add(new OutstandingDueResponse(
                    fee.getId(), fee.getStudent().getId(), fee.getStudent().getFullName(),
                    fee.getPg().getId(), fee.getPg().getName(),
                    fee.getPeriodMonth(), fee.getPeriodYear(),
                    fee.getAmount(), paid, balance, fee.getDueDate(),
                    fee.getDueDate().isBefore(today)
            ));
        }
        result.sort(Comparator.comparing(OutstandingDueResponse::dueDate));
        return result;
    }
}
