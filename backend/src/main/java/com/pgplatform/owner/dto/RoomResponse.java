package com.pgplatform.owner.dto;

import com.pgplatform.owner.Room;
import com.pgplatform.owner.RoomType;
import com.pgplatform.owner.RoomBookingMode;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public record RoomResponse(
        UUID id,
        UUID floorId,
        String roomNumber,
        Integer sharingCount,
        BigDecimal rentPerBed,
        RoomType roomType,
        RoomBookingMode bookingMode,
        BigDecimal dayWiseRate,
        Integer noticePeriodDays,
        BigDecimal securityDeposit,
        List<BedResponse> beds
) {
    public static RoomResponse from(Room room, List<BedResponse> beds) {
        return new RoomResponse(room.getId(), room.getFloor().getId(), room.getRoomNumber(),
                room.getSharingCount(), room.getRentPerBed(), room.getRoomType(), room.getBookingMode(),
                room.getDayWiseRate(), room.getNoticePeriodDays(), room.getSecurityDeposit(), beds);
    }
}
