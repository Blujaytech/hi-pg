package com.pgplatform.report.dto;

import java.util.UUID;

public record OccupancyReportResponse(
        UUID pgId,
        String pgName,
        long totalBeds,
        long occupiedBeds,
        long availableBeds,
        long maintenanceBeds,
        double occupancyPercentage
) {
    public static OccupancyReportResponse of(UUID pgId, String pgName, long occupied, long available, long maintenance) {
        long total = occupied + available + maintenance;
        double pct = total == 0 ? 0.0 : (occupied * 100.0) / total;
        return new OccupancyReportResponse(pgId, pgName, total, occupied, available, maintenance, pct);
    }
}
