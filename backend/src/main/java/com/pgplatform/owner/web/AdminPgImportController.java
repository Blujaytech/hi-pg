package com.pgplatform.owner.web;

import com.pgplatform.owner.importer.PgImportService;
import com.pgplatform.owner.importer.dto.PgImportBatchResponse;
import com.pgplatform.owner.importer.dto.PgImportRowLocationRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/admin/pg-imports")
@PreAuthorize("hasRole('ADMIN')")
public class AdminPgImportController {
    private final PgImportService service;

    public AdminPgImportController(PgImportService service) {
        this.service = service;
    }

    @GetMapping
    public List<PgImportBatchResponse> list() {
        return service.list();
    }

    @GetMapping("/{batchId}")
    public PgImportBatchResponse get(@PathVariable UUID batchId) {
        return service.get(batchId);
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public PgImportBatchResponse upload(@RequestPart("file") MultipartFile file) {
        return service.upload(file);
    }

    @PatchMapping("/{batchId}/rows/{rowId}/location")
    public PgImportBatchResponse updateLocation(@PathVariable UUID batchId, @PathVariable UUID rowId,
                                                @Valid @RequestBody PgImportRowLocationRequest request) {
        return service.updateLocation(batchId, rowId, request);
    }

    @PostMapping("/{batchId}/publish-and-invite")
    public PgImportBatchResponse publishAndInvite(@PathVariable UUID batchId) {
        return service.publishAndInvite(batchId);
    }
}
