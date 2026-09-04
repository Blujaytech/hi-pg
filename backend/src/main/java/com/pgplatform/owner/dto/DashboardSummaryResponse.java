package com.pgplatform.owner.dto;

import java.math.BigDecimal;

public record DashboardSummaryResponse(
        long totalPgs,
        long totalFloors,
        long totalRooms,
        long totalBeds,
        long occupiedBeds,
        long availableBeds,
        long maintenanceBeds,
        double occupancyPercentage,
        long totalActiveStudents,
        BigDecimal totalPendingDues,
        BigDecimal collectedThisMonth,
        BigDecimal expensesThisMonth,
        BigDecimal netThisMonth,
        long openComplaints
) {
    public static DashboardSummaryResponse of(long totalPgs, long totalFloors, long totalRooms,
                                               long occupied, long available, long maintenance, long activeStudents,
                                               BigDecimal totalPendingDues, BigDecimal collectedThisMonth, BigDecimal expensesThisMonth,
                                               long openComplaints) {
        long totalBeds = occupied + available + maintenance;
        double occupancyPercentage = totalBeds == 0 ? 0.0 : Math.round((occupied * 10000.0) / totalBeds) / 100.0;
        BigDecimal netThisMonth = collectedThisMonth.subtract(expensesThisMonth);
        return new DashboardSummaryResponse(totalPgs, totalFloors, totalRooms, totalBeds, occupied, available,
                maintenance, occupancyPercentage, activeStudents, totalPendingDues, collectedThisMonth, expensesThisMonth,
                netThisMonth, openComplaints);
    }
}
