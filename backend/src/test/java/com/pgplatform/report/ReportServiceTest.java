package com.pgplatform.report;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.AuthProviderType;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.billing.FeeService;
import com.pgplatform.billing.PaymentMethod;
import com.pgplatform.billing.dto.FeeCreateRequest;
import com.pgplatform.billing.dto.FeeResponse;
import com.pgplatform.billing.dto.PaymentCreateRequest;
import com.pgplatform.expense.ExpenseCategory;
import com.pgplatform.expense.ExpenseService;
import com.pgplatform.expense.dto.ExpenseCreateRequest;
import com.pgplatform.owner.GenderPreference;
import com.pgplatform.owner.PgService;
import com.pgplatform.owner.dto.PgCreateRequest;
import com.pgplatform.report.dto.MonthlyFinancialSummary;
import com.pgplatform.report.dto.OccupancyReportResponse;
import com.pgplatform.report.dto.OutstandingDueResponse;
import com.pgplatform.student.StudentService;
import com.pgplatform.student.dto.StudentCreateRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class ReportServiceTest extends AbstractIntegrationTest {

    @Autowired
    private UserRepository userRepository;
    @Autowired
    private PgService pgService;
    @Autowired
    private StudentService studentService;
    @Autowired
    private FeeService feeService;
    @Autowired
    private ExpenseService expenseService;
    @Autowired
    private ReportService reportService;

    @Test
    void revenueOccupancyAndOutstandingDuesReflectFeesExpensesAndBeds() {
        User owner = new User();
        owner.setEmail("owner-" + UUID.randomUUID() + "@example.com");
        owner.setFullName("Report Owner");
        owner.setRole(Role.OWNER);
        owner.setProvider(AuthProviderType.LOCAL);
        UUID ownerId = userRepository.save(owner).getId();

        UUID pgId = pgService.create(ownerId, new PgCreateRequest("Lakeview PG", "1 Lake Rd", "Pune",
                null, null, null, null, null, GenderPreference.CO_ED)).id();
        UUID studentId = studentService.create(pgId, ownerId, new StudentCreateRequest(
                "Meera Nair", "9888888888", null, null, null, null, null, LocalDate.now(), null)).id();

        FeeResponse fee = feeService.create(studentId, ownerId, new FeeCreateRequest(
                LocalDate.now().getMonthValue(), LocalDate.now().getYear(),
                new BigDecimal("5000.00"), LocalDate.now().plusDays(3), null));
        feeService.recordPayment(fee.id(), ownerId, new PaymentCreateRequest(
                new BigDecimal("3000.00"), LocalDate.now(), PaymentMethod.CASH, null, null));

        expenseService.create(pgId, ownerId, new ExpenseCreateRequest(
                ExpenseCategory.MAINTENANCE, "Plumbing repair", new BigDecimal("500.00"), LocalDate.now()));

        List<MonthlyFinancialSummary> revenue = reportService.revenueForPg(pgId, ownerId, 3);
        assertThat(revenue).hasSize(3);
        MonthlyFinancialSummary thisMonth = revenue.get(revenue.size() - 1);
        assertThat(thisMonth.year()).isEqualTo(LocalDate.now().getYear());
        assertThat(thisMonth.month()).isEqualTo(LocalDate.now().getMonthValue());
        assertThat(thisMonth.collected()).isEqualByComparingTo("3000.00");
        assertThat(thisMonth.expenses()).isEqualByComparingTo("500.00");
        assertThat(thisMonth.net()).isEqualByComparingTo("2500.00");

        OccupancyReportResponse occupancy = reportService.occupancyForPg(pgId, ownerId);
        assertThat(occupancy.totalBeds()).isZero(); // no rooms/beds created in this test
        assertThat(occupancy.occupancyPercentage()).isEqualTo(0.0);

        List<OutstandingDueResponse> dues = reportService.outstandingDuesForPg(pgId, ownerId);
        assertThat(dues).hasSize(1);
        assertThat(dues.get(0).balance()).isEqualByComparingTo("2000.00");
        assertThat(dues.get(0).studentName()).isEqualTo("Meera Nair");

        List<OutstandingDueResponse> ownerDues = reportService.outstandingDuesForOwner(ownerId);
        assertThat(ownerDues).hasSize(1);
    }
}
