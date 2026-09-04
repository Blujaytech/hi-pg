package com.pgplatform.billing.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.billing.FeeService;
import com.pgplatform.billing.dto.FeeResponse;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.student.StudentRepository;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/**
 * Self-service fee visibility for a logged-in Student -- the read-only
 * counterpart to Phase 12's payment-order endpoints. Only exists for a
 * student who has a linked Student record (i.e. has booked at least once,
 * see Phase 11 / ADR-0018); a student who never booked has nothing to
 * view here yet.
 */
@RestController
@PreAuthorize("hasRole('STUDENT')")
public class StudentFeeController {

    private final FeeService feeService;
    private final StudentRepository studentRepository;

    public StudentFeeController(FeeService feeService, StudentRepository studentRepository) {
        this.feeService = feeService;
        this.studentRepository = studentRepository;
    }

    @GetMapping("/api/v1/student/fees")
    public List<FeeResponse> listMine(@AuthenticationPrincipal UserPrincipal principal) {
        return feeService.listForStudentSelfService(requireStudentId(principal.getId()));
    }

    @GetMapping("/api/v1/student/fees/{feeId}")
    public FeeResponse get(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID feeId) {
        return feeService.getForStudentSelfService(feeId, requireStudentId(principal.getId()));
    }

    private UUID requireStudentId(UUID userId) {
        return studentRepository.findByUserIdAndDeletedAtIsNull(userId)
                .orElseThrow(() -> new NotFoundException("You don't have a student profile yet -- book a bed first"))
                .getId();
    }
}
