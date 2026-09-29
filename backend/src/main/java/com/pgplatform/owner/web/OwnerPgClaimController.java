package com.pgplatform.owner.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.owner.PgClaimService;
import com.pgplatform.owner.dto.OwnerClaimSuggestionResponse;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/owner/claims")
@PreAuthorize("hasRole('OWNER')")
public class OwnerPgClaimController {
    private final PgClaimService service;
    public OwnerPgClaimController(PgClaimService service) { this.service = service; }

    @GetMapping("/suggestions")
    public List<OwnerClaimSuggestionResponse> suggestions(@AuthenticationPrincipal UserPrincipal principal) {
        return service.suggestions(principal.getId());
    }

    @PostMapping("/{pgId}")
    @ResponseStatus(HttpStatus.CREATED)
    public OwnerClaimSuggestionResponse claim(@AuthenticationPrincipal UserPrincipal principal,
                                              @PathVariable UUID pgId) {
        return service.claim(pgId, principal.getId());
    }
}
