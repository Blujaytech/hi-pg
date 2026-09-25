package com.pgplatform.discovery.dto;

import java.util.UUID;

/**
 * One bed in a room's public bed map: an opaque id, its label and whether it
 * can be booked for the requested dates. Deliberately carries no reason a bed
 * is unavailable (booked vs. maintenance) and nothing about who is in it.
 */
public record BedSeatSummary(UUID id, String label, boolean available) {
}
