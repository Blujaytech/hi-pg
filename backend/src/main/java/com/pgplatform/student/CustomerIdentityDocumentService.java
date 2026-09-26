package com.pgplatform.student;

import com.pgplatform.common.ConflictException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.document.DocumentStorageGateway;
import com.pgplatform.student.dto.CustomerIdentityDocumentResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.time.Duration;
import java.util.Set;
import java.util.UUID;

@Service
public class CustomerIdentityDocumentService {
    private static final Logger log = LoggerFactory.getLogger(CustomerIdentityDocumentService.class);
    private static final Logger AUDIT = LoggerFactory.getLogger("AUDIT.customer-identity-document");
    private static final long MAX_FILE_BYTES = 10L * 1024 * 1024;

    private final CustomerProfileRepository profileRepository;
    private final CustomerIdentityDocumentRepository documentRepository;
    private final DocumentStorageGateway storageGateway;
    private final StudentService studentService;

    public CustomerIdentityDocumentService(CustomerProfileRepository profileRepository,
                                           CustomerIdentityDocumentRepository documentRepository,
                                           DocumentStorageGateway storageGateway,
                                           StudentService studentService) {
        this.profileRepository = profileRepository;
        this.documentRepository = documentRepository;
        this.storageGateway = storageGateway;
        this.studentService = studentService;
    }

    @Transactional
    public CustomerIdentityDocumentResponse upload(UUID userId, IdentityType type, byte[] content,
                                                    String fileName, String contentType) {
        validateType(type);
        validateFile(content, fileName, contentType);
        CustomerProfile profile = profileRepository.findByUserIdAndDeletedAtIsNull(userId)
                .orElseThrow(() -> new ConflictException("Save your profile before uploading an ID document"));
        String storageKey = storageGateway.store(content, fileName, contentType);
        boolean cleanupRegistered = false;
        try {
            CustomerIdentityDocument document = documentRepository
                    .findByProfileIdAndDeletedAtIsNull(profile.getId())
                    .orElseGet(CustomerIdentityDocument::new);
            String replacedStorageKey = document.getStorageKey();
            document.setProfile(profile);
            document.setIdentityType(type);
            document.setFileName(fileName);
            document.setContentType(contentType);
            document.setSizeBytes(content.length);
            document.setStorageKey(storageKey);
            profile.setIdentityType(type);
            profile.setIdentityLastFour(null);
            profileRepository.save(profile);
            document = documentRepository.save(document);
            registerStorageCleanup(storageKey, replacedStorageKey);
            cleanupRegistered = true;
            AUDIT.info("action=upload userId={} documentId={} identityType={}",
                    userId, document.getId(), type);
            return CustomerIdentityDocumentResponse.from(document);
        } catch (RuntimeException ex) {
            if (!cleanupRegistered) safeDelete(storageKey, "new object after failed customer upload");
            throw ex;
        }
    }

    @Transactional(readOnly = true)
    public CustomerIdentityDocumentResponse getMine(UUID userId) {
        return CustomerIdentityDocumentResponse.from(requireForUser(userId));
    }

    @Transactional(readOnly = true)
    public String downloadMine(UUID userId) {
        CustomerIdentityDocument document = requireForUser(userId);
        AUDIT.info("action=download_url documentId={} accessedByCustomerId={}", document.getId(), userId);
        return storageGateway.generateSignedUrl(document.getStorageKey(), Duration.ofMinutes(10));
    }

    @Transactional(readOnly = true)
    public CustomerIdentityDocumentResponse getForOwner(UUID studentId, UUID ownerId) {
        return CustomerIdentityDocumentResponse.from(requireForOwner(studentId, ownerId));
    }

    @Transactional(readOnly = true)
    public String downloadForOwner(UUID studentId, UUID ownerId) {
        CustomerIdentityDocument document = requireForOwner(studentId, ownerId);
        AUDIT.info("action=download_url documentId={} studentId={} accessedByOwnerId={}",
                document.getId(), studentId, ownerId);
        return storageGateway.generateSignedUrl(document.getStorageKey(), Duration.ofMinutes(10));
    }

    private CustomerIdentityDocument requireForUser(UUID userId) {
        CustomerProfile profile = profileRepository.findByUserIdAndDeletedAtIsNull(userId)
                .orElseThrow(() -> new NotFoundException("Customer profile not found"));
        return documentRepository.findByProfileIdAndDeletedAtIsNull(profile.getId())
                .orElseThrow(() -> new NotFoundException("Identity document not uploaded"));
    }

    private CustomerIdentityDocument requireForOwner(UUID studentId, UUID ownerId) {
        Student student = studentService.requireOwnedStudent(studentId, ownerId);
        if (student.getUser() == null) throw new NotFoundException("This customer has no uploaded identity document");
        return requireForUser(student.getUser().getId());
    }

    private void validateType(IdentityType type) {
        if (type != IdentityType.AADHAAR && type != IdentityType.PASSPORT) {
            throw new ConflictException("Choose Aadhaar card or passport");
        }
    }

    private void validateFile(byte[] content, String fileName, String contentType) {
        if (content == null || content.length == 0 || content.length > MAX_FILE_BYTES) {
            throw new ConflictException("ID documents must be between 1 byte and 10 MB");
        }
        if (fileName == null || fileName.isBlank()) throw new ConflictException("File name is required");
        if (contentType == null || !Set.of("image/jpeg", "image/png", "application/pdf").contains(contentType)) {
            throw new ConflictException("ID documents must be JPG, PNG, or PDF");
        }
        boolean validSignature = switch (contentType) {
            case "image/jpeg" -> startsWith(content, 0xFF, 0xD8, 0xFF);
            case "image/png" -> startsWith(content, 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A);
            case "application/pdf" -> startsWith(content, 0x25, 0x50, 0x44, 0x46, 0x2D);
            default -> false;
        };
        if (!validSignature) throw new ConflictException("The file content does not match its JPG, PNG, or PDF type");
    }

    private boolean startsWith(byte[] content, int... signature) {
        if (content.length < signature.length) return false;
        for (int i = 0; i < signature.length; i++) {
            if ((content[i] & 0xFF) != signature[i]) return false;
        }
        return true;
    }

    private void registerStorageCleanup(String newStorageKey, String replacedStorageKey) {
        if (!TransactionSynchronizationManager.isSynchronizationActive()) {
            throw new IllegalStateException("Customer document upload requires an active transaction");
        }
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCompletion(int status) {
                if (status == STATUS_COMMITTED) {
                    if (replacedStorageKey != null && !replacedStorageKey.equals(newStorageKey)) {
                        safeDelete(replacedStorageKey, "replaced customer identity object");
                    }
                } else {
                    safeDelete(newStorageKey, "new customer identity object after rollback");
                }
            }
        });
    }

    private void safeDelete(String storageKey, String context) {
        try {
            storageGateway.delete(storageKey);
        } catch (RuntimeException cleanupError) {
            log.error("Could not delete {} from private storage ({})", storageKey, context, cleanupError);
        }
    }
}
