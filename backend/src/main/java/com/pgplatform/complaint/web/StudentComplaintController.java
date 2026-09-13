package com.pgplatform.complaint.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.complaint.ComplaintService;
import com.pgplatform.complaint.dto.ComplaintCreateRequest;
import com.pgplatform.complaint.dto.ComplaintResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/** Student self-service complaint filing and tracking. */
@RestController
@PreAuthorize("hasRole('STUDENT')")
public class StudentComplaintController {

    private final ComplaintService complaintService;

    public StudentComplaintController(ComplaintService complaintService) {
        this.complaintService = complaintService;
    }

    @PostMapping("/api/v1/student/complaints")
    public ResponseEntity<ComplaintResponse> create(@AuthenticationPrincipal UserPrincipal principal,
                                                     @Valid @RequestBody ComplaintCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(complaintService.createForStudent(principal.getId(), request));
    }

    @GetMapping("/api/v1/student/complaints")
    public List<ComplaintResponse> listMine(@AuthenticationPrincipal UserPrincipal principal) {
        return complaintService.listForStudentUser(principal.getId());
    }

    @GetMapping("/api/v1/student/complaints/{complaintId}")
    public ComplaintResponse get(@AuthenticationPrincipal UserPrincipal principal,
                                  @PathVariable UUID complaintId) {
        return complaintService.getForStudentUser(complaintId, principal.getId());
    }
}
