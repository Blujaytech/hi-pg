package com.pgplatform.owner.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.owner.PgService;
import com.pgplatform.owner.dto.PgCreateRequest;
import com.pgplatform.owner.dto.PgResponse;
import com.pgplatform.owner.dto.PgUpdateRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/owner/pgs")
@PreAuthorize("hasRole('OWNER')")
public class PgController {

    private final PgService pgService;

    public PgController(PgService pgService) {
        this.pgService = pgService;
    }

    @PostMapping
    public ResponseEntity<PgResponse> create(@AuthenticationPrincipal UserPrincipal principal,
                                              @Valid @RequestBody PgCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(pgService.create(principal.getId(), request));
    }

    @GetMapping
    public List<PgResponse> list(@AuthenticationPrincipal UserPrincipal principal) {
        return pgService.listForOwner(principal.getId());
    }

    @GetMapping("/{pgId}")
    public PgResponse get(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID pgId) {
        return pgService.getOwned(pgId, principal.getId());
    }

    @PutMapping("/{pgId}")
    public PgResponse update(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID pgId,
                              @Valid @RequestBody PgUpdateRequest request) {
        return pgService.update(pgId, principal.getId(), request);
    }

    @DeleteMapping("/{pgId}")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID pgId) {
        pgService.delete(pgId, principal.getId());
        return ResponseEntity.noContent().build();
    }
}
