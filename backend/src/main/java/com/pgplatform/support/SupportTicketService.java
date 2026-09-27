package com.pgplatform.support;

import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.common.ForbiddenException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.notification.NotificationService;
import com.pgplatform.support.dto.SupportTicketAdminUpdateRequest;
import com.pgplatform.support.dto.SupportTicketCreateRequest;
import com.pgplatform.support.dto.SupportTicketResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
public class SupportTicketService {

    private final SupportTicketRepository repository;
    private final UserRepository userRepository;
    private final NotificationService notificationService;

    public SupportTicketService(SupportTicketRepository repository,
                                UserRepository userRepository,
                                NotificationService notificationService) {
        this.repository = repository;
        this.userRepository = userRepository;
        this.notificationService = notificationService;
    }

    @Transactional
    public SupportTicketResponse create(UUID requesterId, Role authenticatedRole,
                                        SupportTicketCreateRequest request) {
        User requester = userRepository.findByIdAndDeletedAtIsNull(requesterId)
                .orElseThrow(() -> new NotFoundException("Account not found"));
        if (requester.getRole() != authenticatedRole || authenticatedRole == Role.ADMIN) {
            throw new ForbiddenException("Support requests can only be submitted from an owner or customer account");
        }

        SupportTicket ticket = new SupportTicket();
        ticket.setRequester(requester);
        ticket.setRequesterRole(requester.getRole());
        ticket.setCategory(request.category());
        ticket.setSubject(request.subject().trim());
        ticket.setDescription(request.description().trim());
        ticket.setStatus(SupportStatus.OPEN);
        SupportTicket saved = repository.save(ticket);

        userRepository.findAllByRoleAndDeletedAtIsNull(Role.ADMIN).forEach(admin ->
                notificationService.notifyUser(admin.getId(), "New support request",
                        requester.getFullName() + " submitted: " + saved.getSubject()));
        return SupportTicketResponse.from(saved);
    }

    @Transactional(readOnly = true)
    public List<SupportTicketResponse> listMine(UUID requesterId) {
        return repository.findAllByRequesterIdAndDeletedAtIsNullOrderByCreatedAtDesc(requesterId)
                .stream().map(SupportTicketResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public List<SupportTicketResponse> listForAdmin(SupportStatus status) {
        List<SupportTicket> tickets = status == null
                ? repository.findAllByDeletedAtIsNullOrderByCreatedAtDesc()
                : repository.findAllByStatusAndDeletedAtIsNullOrderByCreatedAtDesc(status);
        return tickets.stream().map(SupportTicketResponse::from).toList();
    }

    @Transactional
    public SupportTicketResponse respond(UUID ticketId, UUID adminId,
                                         SupportTicketAdminUpdateRequest request) {
        User admin = userRepository.findByIdAndDeletedAtIsNull(adminId)
                .orElseThrow(() -> new NotFoundException("Administrator account not found"));
        if (admin.getRole() != Role.ADMIN) {
            throw new ForbiddenException("Administrator access is required");
        }
        SupportTicket ticket = repository.findByIdAndDeletedAtIsNull(ticketId)
                .orElseThrow(() -> new NotFoundException("Support request not found"));

        ticket.setStatus(request.status());
        ticket.setAdminResponse(request.response().trim());
        ticket.setRespondedBy(admin);
        ticket.setRespondedAt(Instant.now());
        SupportTicket saved = repository.save(ticket);

        notificationService.notifyUser(saved.getRequester().getId(), "Support request updated",
                "Your request \"" + saved.getSubject() + "\" is now "
                        + saved.getStatus().name().toLowerCase().replace('_', ' ') + ".");
        return SupportTicketResponse.from(saved);
    }
}
