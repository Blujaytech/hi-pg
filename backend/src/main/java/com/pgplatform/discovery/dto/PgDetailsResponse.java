package com.pgplatform.discovery.dto;

import com.pgplatform.owner.GenderPreference;

import java.util.List;
import java.util.UUID;

/**
 * Public PG details page (technical plan §6 Phase 9). Deliberately excludes
 * anything owner-only -- no owner contact info, no student list, no
 * financials. Photos aren't included yet: Document storage (Phase 7b) is
 * still stubbed, so there's nothing real to show -- see docs/decisions.md.
 */
public record PgDetailsResponse(
        UUID id,
        String name,
        String address,
        String city,
        String state,
        String pincode,
        String description,
        GenderPreference genderPreference,
        Double latitude,
        Double longitude,
        long totalBeds,
        long availableBeds,
        List<FloorAvailabilityResponse> floors
) {
}
