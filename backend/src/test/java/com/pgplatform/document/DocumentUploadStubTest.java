package com.pgplatform.document;

import com.pgplatform.AbstractIntegrationTest;
import com.pgplatform.auth.AuthProviderType;
import com.pgplatform.auth.Role;
import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.common.ConflictException;
import com.pgplatform.document.dto.DocumentResponse;
import com.pgplatform.owner.GenderPreference;
import com.pgplatform.owner.PgService;
import com.pgplatform.owner.dto.PgCreateRequest;
import com.pgplatform.student.StudentService;
import com.pgplatform.student.dto.StudentCreateRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Proves the documented contract: with only StubDocumentStorageGateway
 * wired up, an upload attempt fails loudly (not silently) and leaves no
 * half-recorded metadata row behind.
 */
class DocumentUploadStubTest extends AbstractIntegrationTest {

    @Autowired
    private UserRepository userRepository;
    @Autowired
    private PgService pgService;
    @Autowired
    private StudentService studentService;
    @Autowired
    private DocumentService documentService;
    @Autowired
    private DocumentRepository documentRepository;

    @Test
    void uploadFailsWithoutLeavingAnOrphanRow() {
        User owner = new User();
        owner.setEmail("owner-" + UUID.randomUUID() + "@example.com");
        owner.setFullName("Test Owner");
        owner.setRole(Role.OWNER);
        owner.setProvider(AuthProviderType.LOCAL);
        UUID ownerId = userRepository.save(owner).getId();

        UUID pgId = pgService.create(ownerId, new PgCreateRequest("Sunrise PG", "12 MG Road", "Bengaluru",
                null, null, null, null, null, GenderPreference.CO_ED)).id();
        UUID studentId = studentService.create(pgId, ownerId, new StudentCreateRequest(
                "Asha Rao", "9999999999", null, null, null, null, null, LocalDate.now(), null)).id();

        assertThatThrownBy(() -> documentService.upload(
                studentId, ownerId, DocumentType.ID_PROOF,
                "not a real scan".getBytes(StandardCharsets.UTF_8), "aadhaar.pdf", "application/pdf"))
                .isInstanceOf(UnsupportedOperationException.class);

        List<DocumentResponse> documents = documentService.listForStudent(studentId, ownerId);
        assertThat(documents).isEmpty();
    }

    /**
     * The stored content type is what a presigned download later serves the object as, so
     * anything outside the image/PDF allowlist must be refused before it reaches storage.
     */
    @Test
    void uploadRejectsContentTypesOutsideTheAllowlist() {
        User owner = new User();
        owner.setEmail("owner-" + UUID.randomUUID() + "@example.com");
        owner.setFullName("Validation Owner");
        owner.setRole(Role.OWNER);
        owner.setProvider(AuthProviderType.LOCAL);
        UUID ownerId = userRepository.save(owner).getId();

        UUID pgId = pgService.create(ownerId, new PgCreateRequest("Validation PG", "9 MG Road", "Bengaluru",
                null, null, null, null, null, GenderPreference.CO_ED)).id();
        UUID studentId = studentService.create(pgId, ownerId, new StudentCreateRequest(
                "Ravi Kumar", "9888888888", null, null, null, null, null, LocalDate.now(), null)).id();

        assertThatThrownBy(() -> documentService.upload(
                studentId, ownerId, DocumentType.ID_PROOF,
                "<script>alert(1)</script>".getBytes(StandardCharsets.UTF_8), "payload.html", "text/html"))
                .isInstanceOf(ConflictException.class);

        assertThatThrownBy(() -> documentService.upload(
                studentId, ownerId, DocumentType.ID_PROOF,
                new byte[0], "empty.pdf", "application/pdf"))
                .isInstanceOf(ConflictException.class);

        assertThat(documentService.listForStudent(studentId, ownerId)).isEmpty();
    }
}
