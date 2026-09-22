package com.pgplatform.payment.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.payment.DirectPaymentService;
import com.pgplatform.payment.DirectPaymentStatus;
import com.pgplatform.payment.dto.DirectPaymentApproveRequest;
import com.pgplatform.payment.dto.DirectPaymentRejectRequest;
import com.pgplatform.payment.dto.DirectPaymentRequestResponse;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/owner/direct-payment-requests")
@PreAuthorize("hasRole('OWNER')")
public class OwnerDirectPaymentController {
    private final DirectPaymentService service;

    public OwnerDirectPaymentController(DirectPaymentService service) {
        this.service = service;
    }

    @GetMapping
    public List<DirectPaymentRequestResponse> list(@AuthenticationPrincipal UserPrincipal principal,
                                                  @RequestParam(required = false) UUID pgId,
                                                  @RequestParam(required = false) DirectPaymentStatus status) {
        return service.listForOwner(principal.getId(), pgId, status);
    }

    @PostMapping("/{requestId}/approve")
    public DirectPaymentRequestResponse approve(@AuthenticationPrincipal UserPrincipal principal,
                                                @PathVariable UUID requestId,
                                                @Valid @RequestBody DirectPaymentApproveRequest request) {
        return service.approve(requestId, principal.getId(), request);
    }

    @PostMapping("/{requestId}/reject")
    public DirectPaymentRequestResponse reject(@AuthenticationPrincipal UserPrincipal principal,
                                               @PathVariable UUID requestId,
                                               @Valid @RequestBody DirectPaymentRejectRequest request) {
        return service.reject(requestId, principal.getId(), request);
    }
}
