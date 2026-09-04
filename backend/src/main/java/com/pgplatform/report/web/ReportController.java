package com.pgplatform.report.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.report.ReportService;
import com.pgplatform.report.dto.MonthlyFinancialSummary;
import com.pgplatform.report.dto.OccupancyReportResponse;
import com.pgplatform.report.dto.OutstandingDueResponse;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@PreAuthorize("hasRole('OWNER')")
public class ReportController {

    private final ReportService reportService;

    public ReportController(ReportService reportService) {
        this.reportService = reportService;
    }

    @GetMapping("/api/v1/owner/reports/revenue")
    public List<MonthlyFinancialSummary> revenueForOwner(@AuthenticationPrincipal UserPrincipal principal,
                                                           @RequestParam(defaultValue = "6") int months) {
        return reportService.revenueForOwner(principal.getId(), months);
    }

    @GetMapping("/api/v1/owner/pgs/{pgId}/reports/revenue")
    public List<MonthlyFinancialSummary> revenueForPg(@AuthenticationPrincipal UserPrincipal principal,
                                                        @PathVariable UUID pgId,
                                                        @RequestParam(defaultValue = "6") int months) {
        return reportService.revenueForPg(pgId, principal.getId(), months);
    }

    @GetMapping("/api/v1/owner/reports/occupancy")
    public List<OccupancyReportResponse> occupancyForOwner(@AuthenticationPrincipal UserPrincipal principal) {
        return reportService.occupancyForOwner(principal.getId());
    }

    @GetMapping("/api/v1/owner/pgs/{pgId}/reports/occupancy")
    public OccupancyReportResponse occupancyForPg(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID pgId) {
        return reportService.occupancyForPg(pgId, principal.getId());
    }

    @GetMapping("/api/v1/owner/reports/outstanding-dues")
    public List<OutstandingDueResponse> outstandingDuesForOwner(@AuthenticationPrincipal UserPrincipal principal) {
        return reportService.outstandingDuesForOwner(principal.getId());
    }

    @GetMapping("/api/v1/owner/pgs/{pgId}/reports/outstanding-dues")
    public List<OutstandingDueResponse> outstandingDuesForPg(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID pgId) {
        return reportService.outstandingDuesForPg(pgId, principal.getId());
    }
}
