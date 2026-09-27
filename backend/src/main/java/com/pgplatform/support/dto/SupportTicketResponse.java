package com.pgplatform.support.dto;

import com.pgplatform.auth.Role;
import com.pgplatform.support.SupportCategory;
import com.pgplatform.support.SupportStatus;
import com.pgplatform.support.SupportTicket;

import java.time.Instant;
import java.util.UUID;

public record SupportTicketResponse(
        UUID id,
        UUID requesterId,
        String requesterName,
        Role requesterRole,
        String requesterEmail,
        String requesterPhone,
        SupportCategory category,
        String subject,
        String description,
        SupportStatus status,
        String adminResponse,
        String respondedByName,
        Instant respondedAt,
        Instant createdAt,
        Instant updatedAt
) {
    public static SupportTicketResponse from(SupportTicket ticket) {
        return new SupportTicketResponse(
                ticket.getId(),
                ticket.getRequester().getId(),
                ticket.getRequester().getFullName(),
                ticket.getRequesterRole(),
                ticket.getRequester().getEmail(),
                ticket.getRequester().getPhone(),
                ticket.getCategory(),
                ticket.getSubject(),
                ticket.getDescription(),
                ticket.getStatus(),
                ticket.getAdminResponse(),
                ticket.getRespondedBy() == null ? null : ticket.getRespondedBy().getFullName(),
                ticket.getRespondedAt(),
                ticket.getCreatedAt(),
                ticket.getUpdatedAt()
        );
    }
}
