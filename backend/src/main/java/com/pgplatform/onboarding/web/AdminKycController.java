package com.pgplatform.onboarding.web;

import com.pgplatform.onboarding.OwnerKycService;
import com.pgplatform.onboarding.dto.OwnerKycResponse;
import com.pgplatform.onboarding.dto.OwnerKycReviewRequest;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/admin/kyc")
@PreAuthorize("hasRole('ADMIN')")
public class AdminKycController {
    private final OwnerKycService service;
    public AdminKycController(OwnerKycService service) { this.service = service; }

    @GetMapping("/pending")
    public List<OwnerKycResponse> pending() { return service.listPending(); }

    @GetMapping
    public List<OwnerKycResponse> all() { return service.listAll(); }

    @PatchMapping("/{submissionId}")
    public OwnerKycResponse review(@PathVariable UUID submissionId,
                                   @Valid @RequestBody OwnerKycReviewRequest request) {
        return service.review(submissionId, request);
    }

    @GetMapping("/documents/{documentId}/download-url")
    public Map<String, String> download(@PathVariable UUID documentId) {
        return Map.of("url", service.adminDownloadUrl(documentId));
    }
}
