package com.pgplatform.onboarding;

import com.pgplatform.common.ConflictException;
import com.pgplatform.common.ForbiddenException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.document.DocumentStorageGateway;
import com.pgplatform.notification.NotificationService;
import com.pgplatform.onboarding.dto.OwnerKycProfileRequest;
import com.pgplatform.onboarding.dto.OwnerKycResponse;
import com.pgplatform.onboarding.dto.OwnerKycReviewRequest;
import com.pgplatform.owner.PaymentOnboardingStatus;
import com.pgplatform.owner.Pg;
import com.pgplatform.owner.PgRepository;
import com.pgplatform.owner.PgService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

@Service
public class OwnerKycService {
    private static final long MAX_FILE_BYTES = 10L * 1024 * 1024;
    private static final Set<OwnerKycDocumentType> REQUIRED_DOCUMENTS = EnumSet.of(
            OwnerKycDocumentType.PAN_CARD, OwnerKycDocumentType.AADHAAR_FRONT,
            OwnerKycDocumentType.AADHAAR_BACK, OwnerKycDocumentType.OWNER_PHOTO,
            OwnerKycDocumentType.PG_PHOTO);

    private final OwnerKycSubmissionRepository submissionRepository;
    private final OwnerKycDocumentRepository documentRepository;
    private final PgService pgService;
    private final PgRepository pgRepository;
    private final DocumentStorageGateway storageGateway;
    private final NotificationService notificationService;

    public OwnerKycService(OwnerKycSubmissionRepository submissionRepository,
                           OwnerKycDocumentRepository documentRepository, PgService pgService,
                           PgRepository pgRepository, DocumentStorageGateway storageGateway,
                           NotificationService notificationService) {
        this.submissionRepository = submissionRepository;
        this.documentRepository = documentRepository;
        this.pgService = pgService;
        this.pgRepository = pgRepository;
        this.storageGateway = storageGateway;
        this.notificationService = notificationService;
    }

    @Transactional
    public OwnerKycResponse saveProfile(UUID pgId, UUID ownerId, OwnerKycProfileRequest request) {
        Pg pg = pgService.requireOwnedPg(pgId, ownerId);
        if (!pg.getOwner().isPhoneVerified()) {
            throw new ConflictException("Verify the owner's mobile number before starting KYC");
        }
        OwnerKycSubmission submission = submissionRepository.findByPgIdAndDeletedAtIsNull(pgId)
                .orElseGet(OwnerKycSubmission::new);
        if (submission.getId() != null && submission.getStatus() == OwnerKycStatus.SUBMITTED) {
            throw new ConflictException("This KYC submission is already awaiting review");
        }
        if (submission.getStatus() == OwnerKycStatus.VERIFIED) {
            throw new ConflictException("This KYC submission is already verified");
        }
        submission.setPg(pg);
        submission.setLegalName(request.legalName().trim());
        submission.setPanLastFour(request.panLastFour().toUpperCase());
        submission.setAadhaarLastFour(request.aadhaarLastFour());
        submission.setStatus(OwnerKycStatus.DRAFT);
        submission.setReviewNote(null);
        return response(submissionRepository.save(submission));
    }

    @Transactional
    public OwnerKycResponse upload(UUID pgId, UUID ownerId, OwnerKycDocumentType type,
                                   byte[] content, String fileName, String contentType) {
        pgService.requireOwnedPg(pgId, ownerId);
        OwnerKycSubmission submission = requireEditable(pgId);
        validateFile(content, fileName, contentType);
        String storageKey = storageGateway.store(content, fileName, contentType);

        OwnerKycDocument document = documentRepository
                .findBySubmissionIdAndDocumentTypeAndDeletedAtIsNull(submission.getId(), type)
                .orElseGet(OwnerKycDocument::new);
        document.setSubmission(submission);
        document.setDocumentType(type);
        document.setFileName(fileName);
        document.setContentType(contentType);
        document.setSizeBytes((long) content.length);
        document.setStorageKey(storageKey);
        documentRepository.save(document);
        return response(submission);
    }

    @Transactional
    public OwnerKycResponse submit(UUID pgId, UUID ownerId) {
        Pg pg = pgService.requireOwnedPg(pgId, ownerId);
        if (!pg.getOwner().isPhoneVerified()) {
            throw new ConflictException("Verify the owner's mobile number before submitting KYC");
        }
        OwnerKycSubmission submission = requireEditable(pgId);
        Set<OwnerKycDocumentType> uploaded = documentRepository
                .findAllBySubmissionIdAndDeletedAtIsNullOrderByDocumentType(submission.getId()).stream()
                .map(OwnerKycDocument::getDocumentType).collect(java.util.stream.Collectors.toSet());
        Set<OwnerKycDocumentType> missing = EnumSet.copyOf(REQUIRED_DOCUMENTS);
        missing.removeAll(uploaded);
        if (!missing.isEmpty()) {
            throw new ConflictException("Upload all required KYC documents. Missing: " + missing);
        }
        submission.setStatus(OwnerKycStatus.SUBMITTED);
        submission.setSubmittedAt(Instant.now());
        submission.setReviewedAt(null);
        submissionRepository.save(submission);
        pg.setPaymentOnboardingStatus(PaymentOnboardingStatus.PENDING);
        pgRepository.save(pg);
        notificationService.notifyUser(pg.getOwner().getId(), "KYC submitted",
                "Your KYC and payment onboarding request is awaiting admin review.");
        return response(submission);
    }

    @Transactional(readOnly = true)
    public OwnerKycResponse getForOwner(UUID pgId, UUID ownerId) {
        pgService.requireOwnedPg(pgId, ownerId);
        return response(submissionRepository.findByPgIdAndDeletedAtIsNull(pgId)
                .orElseThrow(() -> new NotFoundException("KYC submission not found")));
    }

    @Transactional(readOnly = true)
    public List<OwnerKycResponse> listPending() {
        return submissionRepository.findAllByStatusAndDeletedAtIsNullOrderBySubmittedAtAsc(OwnerKycStatus.SUBMITTED)
                .stream().map(this::response).toList();
    }

    @Transactional
    public OwnerKycResponse review(UUID submissionId, OwnerKycReviewRequest request) {
        OwnerKycSubmission submission = submissionRepository.findByIdAndDeletedAtIsNull(submissionId)
                .orElseThrow(() -> new NotFoundException("KYC submission not found"));
        if (submission.getStatus() != OwnerKycStatus.SUBMITTED) {
            throw new ConflictException("Only submitted KYC records can be reviewed");
        }
        if (request.status() != OwnerKycStatus.VERIFIED && request.status() != OwnerKycStatus.REJECTED) {
            throw new ConflictException("Admin review must verify or reject KYC");
        }
        if (request.status() == OwnerKycStatus.VERIFIED
                && (request.razorpayLinkedAccountId() == null || request.razorpayLinkedAccountId().isBlank())) {
            throw new ConflictException("A Razorpay linked account is required before verification");
        }
        submission.setStatus(request.status());
        submission.setReviewNote(request.reviewNote());
        submission.setReviewedAt(Instant.now());
        submissionRepository.save(submission);

        Pg pg = submission.getPg();
        pg.setPaymentOnboardingStatus(request.status() == OwnerKycStatus.VERIFIED
                ? PaymentOnboardingStatus.VERIFIED : PaymentOnboardingStatus.REJECTED);
        pg.setRazorpayLinkedAccountId(request.status() == OwnerKycStatus.VERIFIED
                ? request.razorpayLinkedAccountId().trim() : null);
        pg.setPlatformCommissionBps(request.platformCommissionBps());
        pgRepository.save(pg);
        notificationService.notifyUser(pg.getOwner().getId(),
                request.status() == OwnerKycStatus.VERIFIED ? "Payments enabled" : "KYC needs changes",
                request.status() == OwnerKycStatus.VERIFIED
                        ? "Your PG can now accept Razorpay payments."
                        : "Your KYC was rejected: " + (request.reviewNote() == null ? "Contact support." : request.reviewNote()));
        return response(submission);
    }

    @Transactional(readOnly = true)
    public String adminDownloadUrl(UUID documentId) {
        OwnerKycDocument document = documentRepository.findByIdAndDeletedAtIsNull(documentId)
                .orElseThrow(() -> new NotFoundException("KYC document not found"));
        return storageGateway.generateSignedUrl(document.getStorageKey(), Duration.ofMinutes(10));
    }

    private OwnerKycSubmission requireEditable(UUID pgId) {
        OwnerKycSubmission submission = submissionRepository.findByPgIdAndDeletedAtIsNull(pgId)
                .orElseThrow(() -> new NotFoundException("Save the KYC profile before uploading documents"));
        if (submission.getStatus() == OwnerKycStatus.SUBMITTED || submission.getStatus() == OwnerKycStatus.VERIFIED) {
            throw new ConflictException("This KYC submission can no longer be edited");
        }
        return submission;
    }

    private OwnerKycResponse response(OwnerKycSubmission submission) {
        return OwnerKycResponse.from(submission,
                documentRepository.findAllBySubmissionIdAndDeletedAtIsNullOrderByDocumentType(submission.getId()));
    }

    private void validateFile(byte[] content, String fileName, String contentType) {
        if (content == null || content.length == 0 || content.length > MAX_FILE_BYTES) {
            throw new ConflictException("KYC files must be between 1 byte and 10 MB");
        }
        if (fileName == null || fileName.isBlank()) throw new ConflictException("File name is required");
        if (contentType == null || !(contentType.startsWith("image/") || "application/pdf".equals(contentType))) {
            throw new ConflictException("KYC documents must be an image or PDF");
        }
    }
}
