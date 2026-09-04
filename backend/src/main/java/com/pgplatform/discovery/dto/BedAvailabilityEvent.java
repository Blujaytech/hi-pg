package com.pgplatform.discovery.dto;

import java.util.UUID;

/** Payload pushed over SSE whenever a PG's bed availability changes (technical plan §6 Phase 10). */
public record BedAvailabilityEvent(UUID pgId, long totalBeds, long availableBeds) {
}
