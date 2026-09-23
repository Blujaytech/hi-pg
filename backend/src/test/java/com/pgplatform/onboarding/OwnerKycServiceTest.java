package com.pgplatform.onboarding;

import com.pgplatform.auth.User;
import com.pgplatform.common.ConflictException;
import com.pgplatform.document.DocumentStorageGateway;
import com.pgplatform.notification.NotificationService;
import com.pgplatform.owner.Pg;
import com.pgplatform.owner.PgRepository;
import com.pgplatform.owner.PgService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class OwnerKycServiceTest {

    @Mock private OwnerKycSubmissionRepository submissionRepository;
    @Mock private OwnerKycDocumentRepository documentRepository;
    @Mock private PgService pgService;
    @Mock private PgRepository pgRepository;
    @Mock private DocumentStorageGateway storageGateway;
    @Mock private NotificationService notificationService;

    private OwnerKycService service;
    private UUID pgId;
    private UUID ownerId;
    private OwnerKycSubmission submission;

    @BeforeEach
    void setUp() {
        service = new OwnerKycService(submissionRepository, documentRepository, pgService,
                pgRepository, storageGateway, notificationService);
        pgId = UUID.randomUUID();
        ownerId = UUID.randomUUID();

        User owner = new User();
        owner.setId(ownerId);
        owner.setFullName("KYC Owner");
        Pg pg = new Pg();
        pg.setId(pgId);
        pg.setName("Test PG");
        pg.setOwner(owner);
        submission = new OwnerKycSubmission();
        submission.setId(UUID.randomUUID());
        submission.setPg(pg);
        submission.setLegalName("KYC Owner");
        submission.setPanLastFour("A123");
        submission.setAadhaarLastFour("4567");

        when(pgService.requireOwnedPg(pgId, ownerId)).thenReturn(pg);
        when(submissionRepository.findByPgIdAndDeletedAtIsNull(pgId)).thenReturn(Optional.of(submission));
    }

    @AfterEach
    void tearDown() {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.clearSynchronization();
        }
    }

    @Test
    void uploadRejectsAFileWhoseBytesDoNotMatchItsDeclaredType() {
        assertThatThrownBy(() -> service.upload(pgId, ownerId, OwnerKycDocumentType.PAN_CARD,
                "not-a-png".getBytes(), "pan.png", "image/png"))
                .isInstanceOf(ConflictException.class)
                .hasMessageContaining("does not match");

        verifyNoInteractions(storageGateway);
    }

    @Test
    void committedReplacementDeletesOnlyThePreviousPrivateObject() {
        byte[] png = new byte[] {(byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1};
        OwnerKycDocument existing = new OwnerKycDocument();
        existing.setId(UUID.randomUUID());
        existing.setSubmission(submission);
        existing.setDocumentType(OwnerKycDocumentType.PAN_CARD);
        existing.setStorageKey("private/documents/old/pan.png");

        when(storageGateway.store(png, "pan.png", "image/png"))
                .thenReturn("private/documents/new/pan.png");
        when(documentRepository.findBySubmissionIdAndDocumentTypeAndDeletedAtIsNull(
                submission.getId(), OwnerKycDocumentType.PAN_CARD)).thenReturn(Optional.of(existing));
        when(documentRepository.save(any(OwnerKycDocument.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(documentRepository.findAllBySubmissionIdAndDeletedAtIsNullOrderByDocumentType(submission.getId()))
                .thenReturn(List.of(existing));

        TransactionSynchronizationManager.initSynchronization();
        service.upload(pgId, ownerId, OwnerKycDocumentType.PAN_CARD, png, "pan.png", "image/png");

        verify(storageGateway, never()).delete(any());
        for (TransactionSynchronization synchronization : TransactionSynchronizationManager.getSynchronizations()) {
            synchronization.afterCompletion(TransactionSynchronization.STATUS_COMMITTED);
        }
        verify(storageGateway).delete("private/documents/old/pan.png");
        verify(storageGateway, never()).delete("private/documents/new/pan.png");
    }
}
