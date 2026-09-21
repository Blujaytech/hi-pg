package com.pgplatform.deposit.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.deposit.DepositService;
import com.pgplatform.deposit.dto.DepositAdjustmentRequest;
import com.pgplatform.deposit.dto.DepositLedgerResponse;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
public class DepositController {
    private final DepositService depositService;

    public DepositController(DepositService depositService) {
        this.depositService = depositService;
    }

    @GetMapping("/api/v1/owner/bookings/{bookingId}/deposit")
    @PreAuthorize("hasRole('OWNER')")
    public DepositLedgerResponse ownerLedger(@AuthenticationPrincipal UserPrincipal principal,
                                             @PathVariable UUID bookingId) {
        return depositService.ownerLedger(bookingId, principal.getId());
    }

    @PostMapping("/api/v1/owner/bookings/{bookingId}/deposit-deductions")
    @PreAuthorize("hasRole('OWNER')")
    public DepositLedgerResponse deduct(@AuthenticationPrincipal UserPrincipal principal,
                                        @PathVariable UUID bookingId,
                                        @Valid @RequestBody DepositAdjustmentRequest request) {
        return depositService.deduct(bookingId, principal.getId(), request);
    }

    @PostMapping("/api/v1/owner/bookings/{bookingId}/deposit-refunds")
    @PreAuthorize("hasRole('OWNER')")
    public DepositLedgerResponse refund(@AuthenticationPrincipal UserPrincipal principal,
                                        @PathVariable UUID bookingId,
                                        @Valid @RequestBody DepositAdjustmentRequest request) {
        return depositService.refund(bookingId, principal.getId(), request);
    }

    @GetMapping("/api/v1/student/bookings/{bookingId}/deposit")
    @PreAuthorize("hasRole('STUDENT')")
    public DepositLedgerResponse studentLedger(@AuthenticationPrincipal UserPrincipal principal,
                                               @PathVariable UUID bookingId) {
        return depositService.studentLedger(bookingId, principal.getId());
    }
}
