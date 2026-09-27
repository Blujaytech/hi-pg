package com.pgplatform.support;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface SupportTicketRepository extends JpaRepository<SupportTicket, UUID> {
    Optional<SupportTicket> findByIdAndDeletedAtIsNull(UUID id);

    List<SupportTicket> findAllByRequesterIdAndDeletedAtIsNullOrderByCreatedAtDesc(UUID requesterId);

    List<SupportTicket> findAllByDeletedAtIsNullOrderByCreatedAtDesc();

    List<SupportTicket> findAllByStatusAndDeletedAtIsNullOrderByCreatedAtDesc(SupportStatus status);
}
