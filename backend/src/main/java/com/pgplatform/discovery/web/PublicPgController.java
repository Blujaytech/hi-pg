package com.pgplatform.discovery.web;

import com.pgplatform.common.PagedResponse;
import com.pgplatform.discovery.BedAvailabilityBroadcaster;
import com.pgplatform.discovery.PgSearchService;
import com.pgplatform.discovery.dto.PgDetailsResponse;
import com.pgplatform.discovery.dto.PgSearchResultResponse;
import com.pgplatform.owner.GenderPreference;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Unauthenticated -- see SecurityConfig's `/api/v1/public/**` permitAll.
 * Nothing under here may expose owner-only data (see PgDetailsResponse's
 * javadoc).
 */
@RestController
public class PublicPgController {

    private final PgSearchService pgSearchService;
    private final BedAvailabilityBroadcaster broadcaster;

    public PublicPgController(PgSearchService pgSearchService, BedAvailabilityBroadcaster broadcaster) {
        this.pgSearchService = pgSearchService;
        this.broadcaster = broadcaster;
    }

    @GetMapping("/api/v1/public/pgs")
    public PagedResponse<PgSearchResultResponse> search(
            @RequestParam(required = false) String city,
            @RequestParam(required = false) GenderPreference genderPreference,
            @RequestParam(required = false) BigDecimal minRent,
            @RequestParam(required = false) BigDecimal maxRent,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return pgSearchService.search(city, genderPreference, minRent, maxRent, page, size);
    }

    @GetMapping("/api/v1/public/pgs/{pgId}")
    public PgDetailsResponse getDetails(@PathVariable UUID pgId) {
        return pgSearchService.getDetails(pgId);
    }

    /**
     * Phase 10 -- Live Bed Availability. Long-lived Server-Sent Events
     * stream: sends the current {@code {pgId, totalBeds, availableBeds}}
     * snapshot immediately on connect, then again every time an owner
     * action changes a bed's status for this PG. No auth required, same as
     * the rest of this controller.
     */
    @GetMapping("/api/v1/public/pgs/{pgId}/availability/stream")
    public SseEmitter streamAvailability(@PathVariable UUID pgId) {
        return broadcaster.subscribe(pgId);
    }
}
