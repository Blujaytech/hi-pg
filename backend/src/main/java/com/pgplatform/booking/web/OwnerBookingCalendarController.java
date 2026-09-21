package com.pgplatform.booking.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.booking.BookingService;
import com.pgplatform.booking.dto.CalendarEntryResponse;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
@PreAuthorize("hasRole('OWNER')")
public class OwnerBookingCalendarController {

    private final BookingService bookingService;

    public OwnerBookingCalendarController(BookingService bookingService) {
        this.bookingService = bookingService;
    }

    @GetMapping("/api/v1/owner/rooms/{roomId}/calendar")
    public List<CalendarEntryResponse> calendar(
            @AuthenticationPrincipal UserPrincipal principal,
            @PathVariable UUID roomId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return bookingService.calendarForRoom(roomId, principal.getId(), from, to);
    }
}
