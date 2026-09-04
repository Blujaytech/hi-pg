package com.pgplatform.complaint.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.complaint.ComplaintService;
import com.pgplatform.complaint.dto.ComplaintCreateRequest;
import com.pgplatform.complaint.dto.ComplaintResponse;
import com.pgplatform.complaint.dto.ComplaintStatusUpdateRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@PreAuthorize("hasRole('OWNER')")
public class ComplaintController {

    private final ComplaintService complaintService;

    public ComplaintController(ComplaintService complaintService) {
        this.complaintService = complaintService;
    }

    @PostMapping("/api/v1/owner/students/{studentId}/complaints")
    public ResponseEntity<ComplaintResponse> create(@AuthenticationPrincipal UserPrincipal principal,
                                                     @PathVariable UUID studentId,
                                                     @Valid @RequestBody ComplaintCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(complaintService.create(studentId, principal.getId(), request));
    }

    @GetMapping("/api/v1/owner/students/{studentId}/complaints")
    public List<ComplaintResponse> listForStudent(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID studentId) {
        return complaintService.listForStudent(studentId, principal.getId());
    }

    @GetMapping("/api/v1/owner/pgs/{pgId}/complaints")
    public List<ComplaintResponse> listForPg(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID pgId) {
        return complaintService.listForPg(pgId, principal.getId());
    }

    @GetMapping("/api/v1/owner/complaints/{complaintId}")
    public ComplaintResponse get(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID complaintId) {
        return complaintService.get(complaintId, principal.getId());
    }

    @PatchMapping("/api/v1/owner/complaints/{complaintId}/status")
    public ComplaintResponse updateStatus(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID complaintId,
                                           @Valid @RequestBody ComplaintStatusUpdateRequest request) {
        return complaintService.updateStatus(complaintId, principal.getId(), request);
    }

    @DeleteMapping("/api/v1/owner/complaints/{complaintId}")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID complaintId) {
        complaintService.delete(complaintId, principal.getId());
        return ResponseEntity.noContent().build();
    }
}
