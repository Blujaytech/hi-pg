package com.pgplatform.owner.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.owner.PgClaimService;
import com.pgplatform.owner.dto.PgInterestResponse;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/student/pgs")
@PreAuthorize("hasRole('STUDENT')")
public class StudentPgInterestController {
    private final PgClaimService service;
    public StudentPgInterestController(PgClaimService service) { this.service = service; }

    @PostMapping("/{pgId}/interest")
    public PgInterestResponse register(@AuthenticationPrincipal UserPrincipal principal,
                                       @PathVariable UUID pgId) {
        return service.registerInterest(pgId, principal.getId());
    }
}
