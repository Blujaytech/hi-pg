package com.pgplatform.auth.web;

import com.pgplatform.auth.AccountDeletionService;
import com.pgplatform.auth.AccountDeletionStorageCleanupService;
import com.pgplatform.auth.CurrentUserProvider;
import com.pgplatform.auth.dto.AccountDeletionRequest;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/me")
public class AccountController {
    private final AccountDeletionService deletionService;
    private final AccountDeletionStorageCleanupService storageCleanupService;

    public AccountController(AccountDeletionService deletionService,
                             AccountDeletionStorageCleanupService storageCleanupService) {
        this.deletionService = deletionService;
        this.storageCleanupService = storageCleanupService;
    }

    @PostMapping("/account-deletion")
    public ResponseEntity<Void> deleteAccount(@Valid @RequestBody AccountDeletionRequest request) {
        UUID auditId = deletionService.deleteCurrentAccount(
                CurrentUserProvider.requireCurrentUser().getId(), request);
        storageCleanupService.cleanupAudit(auditId);
        return ResponseEntity.noContent().build();
    }
}
