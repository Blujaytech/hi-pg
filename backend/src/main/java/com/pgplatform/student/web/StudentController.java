package com.pgplatform.student.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.student.StudentService;
import com.pgplatform.student.dto.AssignBedRequest;
import com.pgplatform.student.dto.StudentCreateRequest;
import com.pgplatform.student.dto.StudentResponse;
import com.pgplatform.student.dto.StudentUpdateRequest;
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
public class StudentController {

    private final StudentService studentService;

    public StudentController(StudentService studentService) {
        this.studentService = studentService;
    }

    @PostMapping("/api/v1/owner/pgs/{pgId}/students")
    public ResponseEntity<StudentResponse> create(@AuthenticationPrincipal UserPrincipal principal,
                                                   @PathVariable UUID pgId,
                                                   @Valid @RequestBody StudentCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(studentService.create(pgId, principal.getId(), request));
    }

    @GetMapping("/api/v1/owner/pgs/{pgId}/students")
    public List<StudentResponse> list(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID pgId) {
        return studentService.listForPg(pgId, principal.getId());
    }

    @GetMapping("/api/v1/owner/students/{studentId}")
    public StudentResponse get(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID studentId) {
        return studentService.get(studentId, principal.getId());
    }

    @PutMapping("/api/v1/owner/students/{studentId}")
    public StudentResponse update(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID studentId,
                                   @Valid @RequestBody StudentUpdateRequest request) {
        return studentService.update(studentId, principal.getId(), request);
    }

    @PostMapping("/api/v1/owner/students/{studentId}/assign-bed")
    public StudentResponse assignBed(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID studentId,
                                      @Valid @RequestBody AssignBedRequest request) {
        return studentService.assignBed(studentId, principal.getId(), request);
    }

    @PostMapping("/api/v1/owner/students/{studentId}/move-out")
    public StudentResponse moveOut(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID studentId) {
        return studentService.moveOut(studentId, principal.getId());
    }

    @DeleteMapping("/api/v1/owner/students/{studentId}")
    public ResponseEntity<Void> delete(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID studentId) {
        studentService.delete(studentId, principal.getId());
        return ResponseEntity.noContent().build();
    }
}
