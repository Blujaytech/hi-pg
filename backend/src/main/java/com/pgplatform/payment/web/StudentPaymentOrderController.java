package com.pgplatform.payment.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.payment.PaymentOrderService;
import com.pgplatform.payment.dto.PaymentOrderCreateRequest;
import com.pgplatform.payment.dto.PaymentOrderResponse;
import com.pgplatform.payment.dto.CheckoutVerificationRequest;
import com.pgplatform.student.StudentRepository;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@PreAuthorize("hasRole('STUDENT')")
public class StudentPaymentOrderController {

    private final PaymentOrderService paymentOrderService;
    private final StudentRepository studentRepository;

    public StudentPaymentOrderController(PaymentOrderService paymentOrderService, StudentRepository studentRepository) {
        this.paymentOrderService = paymentOrderService;
        this.studentRepository = studentRepository;
    }

    /**
     * Returns 501 today (StubRazorpayGateway) -- the contract is real, the
     * outbound Razorpay call is not yet. See docs/decisions.md ADR-0019.
     */
    @PostMapping("/api/v1/student/fees/{feeId}/payment-orders")
    public ResponseEntity<PaymentOrderResponse> createOrder(@AuthenticationPrincipal UserPrincipal principal,
                                                             @PathVariable UUID feeId,
                                                             @Valid @RequestBody PaymentOrderCreateRequest request) {
        UUID studentId = studentRepository.findByUserIdAndDeletedAtIsNull(principal.getId())
                .orElseThrow(() -> new NotFoundException("You don't have a student profile yet -- book a bed first"))
                .getId();
        return ResponseEntity.status(HttpStatus.CREATED).body(paymentOrderService.createOrder(feeId, studentId, request));
    }

    @PostMapping("/api/v1/student/bookings/{bookingId}/payment-orders")
    public ResponseEntity<PaymentOrderResponse> createBookingOrder(
            @AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID bookingId,
            @Valid @RequestBody PaymentOrderCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(paymentOrderService.createBookingOrder(bookingId, principal.getId(), request));
    }

    @PostMapping("/api/v1/student/payment-orders/{paymentOrderId}/verify")
    public PaymentOrderResponse verify(@AuthenticationPrincipal UserPrincipal principal,
                                       @PathVariable UUID paymentOrderId,
                                       @Valid @RequestBody CheckoutVerificationRequest request) {
        return paymentOrderService.verifyCheckout(paymentOrderId, principal.getId(), request);
    }
}
