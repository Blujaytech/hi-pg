package com.pgplatform.owner.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.owner.DashboardService;
import com.pgplatform.owner.dto.DashboardSummaryResponse;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@PreAuthorize("hasRole('OWNER')")
public class DashboardController {

    private final DashboardService dashboardService;

    public DashboardController(DashboardService dashboardService) {
        this.dashboardService = dashboardService;
    }

    @GetMapping("/api/v1/owner/dashboard")
    public DashboardSummaryResponse summary(@AuthenticationPrincipal UserPrincipal principal) {
        return dashboardService.forOwner(principal.getId());
    }

    @GetMapping("/api/v1/owner/pgs/{pgId}/dashboard")
    public DashboardSummaryResponse pgSummary(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID pgId) {
        return dashboardService.forPg(pgId, principal.getId());
    }
}
