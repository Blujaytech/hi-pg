package com.pgplatform.owner.web;

import com.pgplatform.owner.PgService;
import com.pgplatform.owner.dto.PaymentOnboardingReviewRequest;
import com.pgplatform.owner.dto.PgResponse;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/admin/payment-onboarding")
@PreAuthorize("hasRole('ADMIN')")
public class AdminPaymentOnboardingController {
    private final PgService pgService;

    public AdminPaymentOnboardingController(PgService pgService) {
        this.pgService = pgService;
    }

    @GetMapping("/pending")
    public List<PgResponse> pending() {
        return pgService.listPendingPaymentOnboarding();
    }

    @PatchMapping("/{pgId}")
    public PgResponse review(@PathVariable UUID pgId,
                             @Valid @RequestBody PaymentOnboardingReviewRequest request) {
        return pgService.reviewPaymentOnboarding(pgId, request);
    }
}
