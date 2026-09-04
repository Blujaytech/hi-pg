package com.pgplatform.discovery.dto;

import java.util.UUID;

/** Just enough to let a student pick a specific bed when booking (Phase 11) -- no PII, an opaque id + label. */
public record AvailableBedSummary(UUID id, String label) {
}
