package com.pgplatform.booking.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.booking.BookingService;
import com.pgplatform.booking.dto.BookingCreateRequest;
import com.pgplatform.booking.dto.BookingResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@PreAuthorize("hasRole('STUDENT')")
public class StudentBookingController {

    private final BookingService bookingService;

    public StudentBookingController(BookingService bookingService) {
        this.bookingService = bookingService;
    }

    @PostMapping("/api/v1/student/bookings")
    public ResponseEntity<BookingResponse> book(@AuthenticationPrincipal UserPrincipal principal,
                                                 @Valid @RequestBody BookingCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(bookingService.book(principal.getId(), request));
    }

    @GetMapping("/api/v1/student/bookings")
    public List<BookingResponse> listMine(@AuthenticationPrincipal UserPrincipal principal) {
        return bookingService.listForUser(principal.getId());
    }

    @GetMapping("/api/v1/student/bookings/{bookingId}")
    public BookingResponse get(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID bookingId) {
        return bookingService.get(bookingId, principal.getId());
    }

    @PostMapping("/api/v1/student/bookings/{bookingId}/cancel")
    public BookingResponse cancel(@AuthenticationPrincipal UserPrincipal principal, @PathVariable UUID bookingId,
                                   @RequestParam(required = false) String reason) {
        return bookingService.cancel(bookingId, principal.getId(), reason);
    }
}
