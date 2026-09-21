package com.pgplatform.autopay.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.autopay.AutoPayService;
import com.pgplatform.autopay.dto.AutoPayCreateRequest;
import com.pgplatform.autopay.dto.AutoPayResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/student/autopay")
@PreAuthorize("hasRole('STUDENT')")
public class StudentAutoPayController {
    private final AutoPayService autoPayService;

    public StudentAutoPayController(AutoPayService autoPayService) {
        this.autoPayService = autoPayService;
    }

    @PostMapping
    public ResponseEntity<AutoPayResponse> create(@AuthenticationPrincipal UserPrincipal principal,
                                                   @Valid @RequestBody AutoPayCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(autoPayService.create(principal.getId(), request));
    }

    @GetMapping
    public AutoPayResponse get(@AuthenticationPrincipal UserPrincipal principal) {
        return autoPayService.get(principal.getId());
    }
}
