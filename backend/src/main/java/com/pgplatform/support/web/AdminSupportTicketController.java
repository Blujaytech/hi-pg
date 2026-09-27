package com.pgplatform.support.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.support.SupportStatus;
import com.pgplatform.support.SupportTicketService;
import com.pgplatform.support.dto.SupportTicketAdminUpdateRequest;
import com.pgplatform.support.dto.SupportTicketResponse;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/admin/support/tickets")
@PreAuthorize("hasRole('ADMIN')")
public class AdminSupportTicketController {

    private final SupportTicketService service;

    public AdminSupportTicketController(SupportTicketService service) {
        this.service = service;
    }

    @GetMapping
    public List<SupportTicketResponse> list(@RequestParam(required = false) SupportStatus status) {
        return service.listForAdmin(status);
    }

    @PatchMapping("/{ticketId}")
    public SupportTicketResponse respond(@AuthenticationPrincipal UserPrincipal principal,
                                         @PathVariable UUID ticketId,
                                         @Valid @RequestBody SupportTicketAdminUpdateRequest request) {
        return service.respond(ticketId, principal.getId(), request);
    }
}
