package com.pgplatform.support.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.support.SupportTicketService;
import com.pgplatform.support.dto.SupportTicketCreateRequest;
import com.pgplatform.support.dto.SupportTicketResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/support/tickets")
@PreAuthorize("hasAnyRole('OWNER', 'STUDENT')")
public class SupportTicketController {

    private final SupportTicketService service;

    public SupportTicketController(SupportTicketService service) {
        this.service = service;
    }

    @PostMapping
    public ResponseEntity<SupportTicketResponse> create(@AuthenticationPrincipal UserPrincipal principal,
                                                        @Valid @RequestBody SupportTicketCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(service.create(principal.getId(), principal.getRole(), request));
    }

    @GetMapping
    public List<SupportTicketResponse> mine(@AuthenticationPrincipal UserPrincipal principal) {
        return service.listMine(principal.getId());
    }
}
