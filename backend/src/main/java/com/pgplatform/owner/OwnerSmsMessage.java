package com.pgplatform.owner;

import com.pgplatform.common.BaseEntity;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(name = "owner_sms_messages")
public class OwnerSmsMessage extends BaseEntity {
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "pg_id", nullable = false)
    private Pg pg;

    @Column(name = "event_key", nullable = false, length = 100)
    private String eventKey;

    @Column(name = "recipient_mobile", nullable = false, length = 20)
    private String recipientMobile;

    @Column(name = "message_text", nullable = false, columnDefinition = "text")
    private String messageText;

    @Column(nullable = false, length = 32)
    private String provider;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 24)
    private OwnerSmsStatus status;

    @Column(name = "provider_message_id")
    private String providerMessageId;

    @Column(name = "failure_reason", columnDefinition = "text")
    private String failureReason;
}
