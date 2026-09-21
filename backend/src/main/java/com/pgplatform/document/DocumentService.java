package com.pgplatform.document;

import com.pgplatform.common.ConflictException;
import com.pgplatform.common.ForbiddenException;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.document.dto.DocumentResponse;
import com.pgplatform.owner.PgService;
import com.pgplatform.student.Student;
import com.pgplatform.student.StudentService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.util.List;
import java.util.UUID;

@Service
public class DocumentService {

    /**
     * Phase 15 security audit finding (technical plan §8: "structured audit logging for
     * anything touching student documents or payments ... goes beyond 'secure storage' to
     * 'provable who-accessed-it'"). A dedicated logger name, rather than the class's own,
     * so log aggregation can route/retain these lines separately from ordinary application
     * logs -- this is a first step (a searchable, structured log line per access), not the
     * full queryable audit-trail table a mature deployment would eventually want.
     */
    private static final Logger AUDIT = LoggerFactory.getLogger("AUDIT.document");

    private static final long MAX_FILE_BYTES = 10L * 1024 * 1024;

    private final DocumentRepository documentRepository;
    private final DocumentStorageGateway storageGateway;
    private final StudentService studentService;
    private final PgService pgService;

    public DocumentService(DocumentRepository documentRepository, DocumentStorageGateway storageGateway,
                            StudentService studentService, PgService pgService) {
        this.documentRepository = documentRepository;
        this.storageGateway = storageGateway;
        this.studentService = studentService;
        this.pgService = pgService;
    }

    /**
     * Stores bytes before metadata so a failed object write cannot leave a
     * Document row pointing at a missing object. Disabled local storage fails
     * closed through StubDocumentStorageGateway before persistence.
     */
    @Transactional
    public DocumentResponse upload(UUID studentId, UUID ownerId, DocumentType documentType,
                                    byte[] content, String fileName, String contentType) {
        Student student = studentService.requireOwnedStudent(studentId, ownerId);
        validateFile(content, fileName, contentType);

        String storageKey = storageGateway.store(content, fileName, contentType);

        Document document = new Document();
        document.setStudent(student);
        document.setPg(student.getPg());
        document.setDocumentType(documentType);
        document.setFileName(fileName);
        document.setContentType(contentType);
        document.setSizeBytes(content.length);
        document.setStorageKey(storageKey);

        return DocumentResponse.from(documentRepository.save(document));
    }

    @Transactional(readOnly = true)
    public List<DocumentResponse> listForStudent(UUID studentId, UUID ownerId) {
        studentService.requireOwnedStudent(studentId, ownerId);
        return documentRepository.findAllByStudentIdAndDeletedAtIsNullOrderByCreatedAtDesc(studentId)
                .stream().map(DocumentResponse::from).toList();
    }

    @Transactional(readOnly = true)
    public String downloadUrl(UUID documentId, UUID ownerId) {
        Document document = requireOwnedDocument(documentId, ownerId);
        AUDIT.info("action=download_url documentId={} studentId={} documentType={} accessedByOwnerId={}",
                document.getId(), document.getStudent().getId(), document.getDocumentType(), ownerId);
        return storageGateway.generateSignedUrl(document.getStorageKey(), Duration.ofMinutes(15));
    }

    @Transactional
    public void delete(UUID documentId, UUID ownerId) {
        Document document = requireOwnedDocument(documentId, ownerId);
        AUDIT.info("action=delete documentId={} studentId={} documentType={} deletedByOwnerId={}",
                document.getId(), document.getStudent().getId(), document.getDocumentType(), ownerId);
        if (document.getStorageKey() != null) {
            storageGateway.delete(document.getStorageKey());
        }
        document.markDeleted();
        documentRepository.save(document);
    }

    /**
     * Student documents went in unvalidated while OwnerKycService validated its own
     * uploads. The stored content type is what a presigned GET later serves the file
     * as, so an uploaded `text/html` came back as a live page on the storage origin --
     * an arbitrary-content host attached to the PG's own bucket. Same allowlist and
     * ceiling as the KYC path.
     */
    private void validateFile(byte[] content, String fileName, String contentType) {
        if (content == null || content.length == 0 || content.length > MAX_FILE_BYTES) {
            throw new ConflictException("Documents must be between 1 byte and 10 MB");
        }
        if (fileName == null || fileName.isBlank()) {
            throw new ConflictException("File name is required");
        }
        if (contentType == null || !(contentType.startsWith("image/") || "application/pdf".equals(contentType))) {
            throw new ConflictException("Documents must be an image or a PDF");
        }
    }

    private Document requireOwnedDocument(UUID documentId, UUID ownerId) {
        Document document = documentRepository.findByIdAndDeletedAtIsNull(documentId)
                .orElseThrow(() -> new NotFoundException("Document not found"));
        if (!document.getPg().getOwner().getId().equals(ownerId)) {
            throw new ForbiddenException("You do not have access to this document");
        }
        return document;
    }
}
