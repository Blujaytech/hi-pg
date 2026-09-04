package com.pgplatform.expense.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.expense.ExpenseService;
import com.pgplatform.expense.dto.ExpenseCreateRequest;
import com.pgplatform.expense.dto.ExpenseResponse;
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
public class ExpenseController {

    private final ExpenseService expenseService;

    public ExpenseController(ExpenseService expenseService) {
        this.expenseService = expenseService;
    }

    @PostMapping("/api/v1/owner/pgs/{pgId}/expenses")
    public ResponseEntity<ExpenseResponse> create(@AuthenticationPrincipal UserPrincipal principal,
                                                   @PathVariable UUID pgId,
                                                   @Valid @RequestBody ExpenseCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(expenseService.create(pgId, principal.getId(), request));
    }

    @GetMapping("/api/v1/owner/pgs/{pgId}/expenses")
    public List<ExpenseResponse> list(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID pgId) {
        return expenseService.listForPg(pgId, principal.getId());
    }

    @PutMapping("/api/v1/owner/expenses/{expenseId}")
    public ExpenseResponse update(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID expenseId,
                                   @Valid @RequestBody ExpenseCreateRequest request) {
        return expenseService.update(expenseId, principal.getId(), request);
    }

    @DeleteMapping("/api/v1/owner/expenses/{expenseId}")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID expenseId) {
        expenseService.delete(expenseId, principal.getId());
        return ResponseEntity.noContent().build();
    }
}
