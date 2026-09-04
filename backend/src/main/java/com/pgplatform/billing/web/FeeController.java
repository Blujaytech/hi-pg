package com.pgplatform.billing.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.billing.FeeService;
import com.pgplatform.billing.dto.FeeCreateRequest;
import com.pgplatform.billing.dto.FeeResponse;
import com.pgplatform.billing.dto.PaymentCreateRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@PreAuthorize("hasRole('OWNER')")
public class FeeController {

    private final FeeService feeService;

    public FeeController(FeeService feeService) {
        this.feeService = feeService;
    }

    @PostMapping("/api/v1/owner/students/{studentId}/fees")
    public ResponseEntity<FeeResponse> create(@AuthenticationPrincipal UserPrincipal principal,
                                               @PathVariable UUID studentId,
                                               @Valid @RequestBody FeeCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(feeService.create(studentId, principal.getId(), request));
    }

    @GetMapping("/api/v1/owner/students/{studentId}/fees")
    public List<FeeResponse> listForStudent(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID studentId) {
        return feeService.listForStudent(studentId, principal.getId());
    }

    @GetMapping("/api/v1/owner/pgs/{pgId}/fees")
    public List<FeeResponse> listForPg(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID pgId) {
        return feeService.listForPg(pgId, principal.getId());
    }

    @GetMapping("/api/v1/owner/fees/{feeId}")
    public FeeResponse get(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID feeId) {
        return feeService.get(feeId, principal.getId());
    }

    @PostMapping("/api/v1/owner/fees/{feeId}/payments")
    public FeeResponse recordPayment(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID feeId,
                                      @Valid @RequestBody PaymentCreateRequest request) {
        return feeService.recordPayment(feeId, principal.getId(), request);
    }

    @DeleteMapping("/api/v1/owner/fees/{feeId}")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID feeId) {
        feeService.delete(feeId, principal.getId());
        return ResponseEntity.noContent().build();
    }
}
