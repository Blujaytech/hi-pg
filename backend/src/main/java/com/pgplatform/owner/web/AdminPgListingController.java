package com.pgplatform.owner.web;

import com.pgplatform.owner.AdminPgListingService;
import com.pgplatform.owner.dto.AdminPgListingRequest;
import com.pgplatform.owner.dto.AdminPgListingResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/admin/pg-listings")
@PreAuthorize("hasRole('ADMIN')")
public class AdminPgListingController {
    private final AdminPgListingService service;

    public AdminPgListingController(AdminPgListingService service) { this.service = service; }

    @GetMapping
    public List<AdminPgListingResponse> list() { return service.list(); }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public AdminPgListingResponse create(@Valid @RequestBody AdminPgListingRequest request) {
        return service.create(request);
    }

    @PutMapping("/{pgId}")
    public AdminPgListingResponse update(@PathVariable UUID pgId,
                                         @Valid @RequestBody AdminPgListingRequest request) {
        return service.update(pgId, request);
    }
}
