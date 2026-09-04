package com.pgplatform.document.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.document.DocumentService;
import com.pgplatform.document.DocumentType;
import com.pgplatform.document.dto.DocumentResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@PreAuthorize("hasRole('OWNER')")
public class DocumentController {

    private final DocumentService documentService;

    public DocumentController(DocumentService documentService) {
        this.documentService = documentService;
    }

    /**
     * Multipart upload. With only the stub storage gateway wired up, this
     * always responds 501 -- see DocumentService.upload's javadoc. The
     * endpoint is real so mobile/web can build the upload screen against it
     * now and it starts working the moment real storage is configured.
     */
    @PostMapping(value = "/api/v1/owner/students/{studentId}/documents", consumes = "multipart/form-data")
    public ResponseEntity<DocumentResponse> upload(@AuthenticationPrincipal UserPrincipal principal,
                                                    @PathVariable UUID studentId,
                                                    @RequestParam DocumentType documentType,
                                                    @RequestPart MultipartFile file) {
        try {
            DocumentResponse response = documentService.upload(
                    studentId, principal.getId(), documentType,
                    file.getBytes(), file.getOriginalFilename(), file.getContentType());
            return ResponseEntity.status(HttpStatus.CREATED).body(response);
        } catch (IOException e) {
            throw new UncheckedIOException("Failed to read uploaded file", e);
        }
    }

    @GetMapping("/api/v1/owner/students/{studentId}/documents")
    public List<DocumentResponse> list(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID studentId) {
        return documentService.listForStudent(studentId, principal.getId());
    }

    @GetMapping("/api/v1/owner/documents/{documentId}/download-url")
    public Map<String, String> downloadUrl(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID documentId) {
        return Map.of("url", documentService.downloadUrl(documentId, principal.getId()));
    }

    @DeleteMapping("/api/v1/owner/documents/{documentId}")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID documentId) {
        documentService.delete(documentId, principal.getId());
        return ResponseEntity.noContent().build();
    }
}
