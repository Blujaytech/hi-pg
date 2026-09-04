package com.pgplatform.billing.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.billing.ReceiptService;
import com.pgplatform.billing.dto.ReceiptResponse;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@PreAuthorize("hasRole('OWNER')")
public class ReceiptController {

    private final ReceiptService receiptService;

    public ReceiptController(ReceiptService receiptService) {
        this.receiptService = receiptService;
    }

    @GetMapping("/api/v1/owner/students/{studentId}/receipts")
    public List<ReceiptResponse> listForStudent(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID studentId) {
        return receiptService.listForStudent(studentId, principal.getId());
    }

    @GetMapping("/api/v1/owner/pgs/{pgId}/receipts")
    public List<ReceiptResponse> listForPg(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID pgId) {
        return receiptService.listForPg(pgId, principal.getId());
    }

    @GetMapping("/api/v1/owner/receipts/{receiptId}")
    public ReceiptResponse get(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID receiptId) {
        return receiptService.get(receiptId, principal.getId());
    }
}
