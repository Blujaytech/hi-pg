package com.pgplatform.onboarding.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.onboarding.OwnerKycDocumentType;
import com.pgplatform.onboarding.OwnerKycService;
import com.pgplatform.onboarding.dto.OwnerKycProfileRequest;
import com.pgplatform.onboarding.dto.OwnerKycResponse;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/owner/pgs/{pgId}/kyc")
@PreAuthorize("hasRole('OWNER')")
public class OwnerKycController {
    private final OwnerKycService service;
    public OwnerKycController(OwnerKycService service) { this.service = service; }

    @PutMapping
    public OwnerKycResponse save(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID pgId,
                                 @Valid @RequestBody OwnerKycProfileRequest request) {
        return service.saveProfile(pgId, principal.getId(), request);
    }

    @PostMapping(value = "/documents", consumes = "multipart/form-data")
    public OwnerKycResponse upload(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID pgId,
                                   @RequestParam("documentType") OwnerKycDocumentType documentType,
                                   @RequestPart("file") MultipartFile file) {
        try {
            return service.upload(pgId, principal.getId(), documentType, file.getBytes(),
                    file.getOriginalFilename(), file.getContentType());
        } catch (IOException e) {
            throw new UncheckedIOException("Could not read KYC document", e);
        }
    }

    @PostMapping("/submit")
    public OwnerKycResponse submit(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID pgId) {
        return service.submit(pgId, principal.getId());
    }

    @GetMapping
    public OwnerKycResponse get(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID pgId) {
        return service.getForOwner(pgId, principal.getId());
    }
}
