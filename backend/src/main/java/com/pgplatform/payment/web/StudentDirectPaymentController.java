package com.pgplatform.payment.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.payment.DirectPaymentService;
import com.pgplatform.payment.dto.DirectPaymentDetailsResponse;
import com.pgplatform.payment.dto.DirectPaymentRequestResponse;
import com.pgplatform.payment.dto.DirectPaymentSubmitRequest;
import jakarta.validation.Valid;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/student/bookings/{bookingId}")
@PreAuthorize("hasRole('STUDENT')")
public class StudentDirectPaymentController {
    private final DirectPaymentService service;

    public StudentDirectPaymentController(DirectPaymentService service) {
        this.service = service;
    }

    @GetMapping("/direct-payment-details")
    public ResponseEntity<DirectPaymentDetailsResponse> details(@AuthenticationPrincipal UserPrincipal principal,
                                                               @PathVariable UUID bookingId) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore())
                .body(service.details(bookingId, principal.getId()));
    }

    @PostMapping("/direct-payment-details")
    public ResponseEntity<DirectPaymentDetailsResponse> select(
            @AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID bookingId) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore())
                .body(service.selectDirectPayment(bookingId, principal.getId()));
    }

    @PostMapping("/direct-payment-requests")
    public ResponseEntity<DirectPaymentRequestResponse> submit(
            @AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID bookingId,
            @Valid @RequestBody DirectPaymentSubmitRequest request) {
        return ResponseEntity.status(201).body(service.submit(bookingId, principal.getId(), request));
    }

    @GetMapping({"/direct-payment-request", "/direct-payment-requests/current"})
    public DirectPaymentRequestResponse current(@AuthenticationPrincipal UserPrincipal principal,
                                                @PathVariable UUID bookingId) {
        return service.currentForCustomer(bookingId, principal.getId());
    }
}
