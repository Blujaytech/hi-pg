package com.pgplatform.document.web;

import com.pgplatform.document.DocumentStorageGateway;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/admin/storage")
@PreAuthorize("hasRole('ADMIN')")
public class AdminDocumentStorageController {
    private final DocumentStorageGateway storageGateway;

    public AdminDocumentStorageController(DocumentStorageGateway storageGateway) {
        this.storageGateway = storageGateway;
    }

    @PostMapping("/verify")
    public ResponseEntity<Map<String, String>> verify() {
        storageGateway.verifyReadWriteAccess();
        return ResponseEntity.ok(Map.of("status", "AVAILABLE"));
    }
}
