package com.pgplatform.student.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.booking.BookingType;
import com.pgplatform.student.CustomerProfileService;
import com.pgplatform.student.dto.BookingEligibilityResponse;
import com.pgplatform.student.dto.CustomerProfileResponse;
import com.pgplatform.student.dto.CustomerProfileUpdateRequest;
import com.pgplatform.student.dto.StudentPhoneOtpRequest;
import com.pgplatform.student.dto.StudentPhoneOtpVerifyRequest;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/student/profile")
@PreAuthorize("hasRole('STUDENT')")
public class CustomerProfileController {
    private final CustomerProfileService service;

    public CustomerProfileController(CustomerProfileService service) {
        this.service = service;
    }

    @GetMapping
    public CustomerProfileResponse get(@AuthenticationPrincipal UserPrincipal principal) {
        return service.get(principal.getId());
    }

    @PutMapping
    public CustomerProfileResponse update(@AuthenticationPrincipal UserPrincipal principal,
                                          @Valid @RequestBody CustomerProfileUpdateRequest request,
                                          HttpServletRequest servletRequest) {
        return service.update(principal.getId(), request, clientIp(servletRequest),
                servletRequest.getHeader("User-Agent"), servletRequest.getLocale().toLanguageTag());
    }

    @GetMapping("/booking-eligibility")
    public BookingEligibilityResponse eligibility(@AuthenticationPrincipal UserPrincipal principal,
                                                  @RequestParam BookingType bookingType) {
        return service.eligibility(principal.getId(), bookingType);
    }

    @PostMapping("/phone/otp/request")
    public ResponseEntity<Void> requestPhoneOtp(@AuthenticationPrincipal UserPrincipal principal,
                                                @Valid @RequestBody StudentPhoneOtpRequest request) {
        service.requestPhoneOtp(principal.getId(), request);
        return ResponseEntity.accepted().build();
    }

    @PostMapping("/phone/otp/verify")
    public CustomerProfileResponse verifyPhoneOtp(@AuthenticationPrincipal UserPrincipal principal,
                                                  @Valid @RequestBody StudentPhoneOtpVerifyRequest request) {
        return service.verifyPhoneOtp(principal.getId(), request);
    }

    private String clientIp(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        return forwarded == null || forwarded.isBlank()
                ? request.getRemoteAddr() : forwarded.split(",", 2)[0].trim();
    }
}
