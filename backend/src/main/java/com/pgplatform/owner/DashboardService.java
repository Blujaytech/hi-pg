package com.pgplatform.owner;

import com.pgplatform.billing.FeeRepository;
import com.pgplatform.complaint.ComplaintRepository;
import com.pgplatform.expense.ExpenseRepository;
import com.pgplatform.owner.dto.DashboardSummaryResponse;
import com.pgplatform.payment.DirectPaymentRequestRepository;
import com.pgplatform.payment.PaymentOrderRepository;
import com.pgplatform.student.StudentRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.Instant;
import java.time.ZoneId;
import java.math.BigDecimal;
import java.util.UUID;

/**
 * Thin by design (technical plan §6 Phase 3: "thin at first -- counts,
 * occupancy %, grows richer once fees/payments exist"). Now that Phase 5
 * exists, this also reports this-month collections/expenses/net and total
 * pending dues -- still read-only aggregation, no writes happen here.
 */
@Service
public class DashboardService {

    private static final ZoneId BUSINESS_ZONE = ZoneId.of("Asia/Kolkata");

    private final PgRepository pgRepository;
    private final FloorRepository floorRepository;
    private final RoomRepository roomRepository;
    private final BedRepository bedRepository;
    private final StudentRepository studentRepository;
    private final FeeRepository feeRepository;
    private final ExpenseRepository expenseRepository;
    private final ComplaintRepository complaintRepository;
    private final PgService pgService;
    private final DirectPaymentRequestRepository directPaymentRepository;
    private final PaymentOrderRepository paymentOrderRepository;

    public DashboardService(PgRepository pgRepository, FloorRepository floorRepository, RoomRepository roomRepository,
                             BedRepository bedRepository, StudentRepository studentRepository,
                             FeeRepository feeRepository, ExpenseRepository expenseRepository,
                             ComplaintRepository complaintRepository, PgService pgService,
                             DirectPaymentRequestRepository directPaymentRepository,
                             PaymentOrderRepository paymentOrderRepository) {
        this.pgRepository = pgRepository;
        this.floorRepository = floorRepository;
        this.roomRepository = roomRepository;
        this.bedRepository = bedRepository;
        this.studentRepository = studentRepository;
        this.feeRepository = feeRepository;
        this.expenseRepository = expenseRepository;
        this.complaintRepository = complaintRepository;
        this.pgService = pgService;
        this.directPaymentRepository = directPaymentRepository;
        this.paymentOrderRepository = paymentOrderRepository;
    }

    @Transactional(readOnly = true)
    public DashboardSummaryResponse forOwner(UUID ownerId) {
        LocalDate monthStart = LocalDate.now().withDayOfMonth(1);
        LocalDate today = LocalDate.now();
        Instant from = monthStart.atStartOfDay(BUSINESS_ZONE).toInstant();
        Instant to = today.plusDays(1).atStartOfDay(BUSINESS_ZONE).toInstant();
        BigDecimal collected = feeRepository.sumCollectedByOwnerIdBetween(ownerId, monthStart, today)
                .add(paymentOrderRepository.sumPaidBookingOrdersForOwner(ownerId, from, to))
                .add(directPaymentRepository.sumApprovedForOwner(ownerId, from, to));

        return DashboardSummaryResponse.of(
                pgRepository.countByOwnerIdAndDeletedAtIsNull(ownerId),
                floorRepository.countByOwnerId(ownerId),
                roomRepository.countByOwnerId(ownerId),
                bedRepository.countByOwnerIdAndStatus(ownerId, BedStatus.OCCUPIED),
                bedRepository.countByOwnerIdAndStatus(ownerId, BedStatus.AVAILABLE),
                bedRepository.countByOwnerIdAndStatus(ownerId, BedStatus.MAINTENANCE),
                studentRepository.countActiveByOwnerId(ownerId),
                feeRepository.sumPendingDuesByOwnerId(ownerId),
                collected,
                expenseRepository.sumByOwnerIdBetween(ownerId, monthStart, today),
                complaintRepository.countOpenByOwnerId(ownerId)
        );
    }

    @Transactional(readOnly = true)
    public DashboardSummaryResponse forPg(UUID pgId, UUID ownerId) {
        pgService.requireOwnedPg(pgId, ownerId);
        LocalDate monthStart = LocalDate.now().withDayOfMonth(1);
        LocalDate today = LocalDate.now();
        Instant from = monthStart.atStartOfDay(BUSINESS_ZONE).toInstant();
        Instant to = today.plusDays(1).atStartOfDay(BUSINESS_ZONE).toInstant();
        BigDecimal collected = feeRepository.sumCollectedByPgIdBetween(pgId, monthStart, today)
                .add(paymentOrderRepository.sumPaidBookingOrdersForPg(pgId, from, to))
                .add(directPaymentRepository.sumApprovedForPg(pgId, from, to));

        return DashboardSummaryResponse.of(
                1,
                floorRepository.countByPgIdAndDeletedAtIsNull(pgId),
                roomRepository.countByPgId(pgId),
                bedRepository.countByPgIdAndStatus(pgId, BedStatus.OCCUPIED),
                bedRepository.countByPgIdAndStatus(pgId, BedStatus.AVAILABLE),
                bedRepository.countByPgIdAndStatus(pgId, BedStatus.MAINTENANCE),
                studentRepository.countActiveByPgId(pgId),
                feeRepository.sumPendingDuesByPgId(pgId),
                collected,
                expenseRepository.sumByPgIdBetween(pgId, monthStart, today),
                complaintRepository.countOpenByPgId(pgId)
        );
    }
}
