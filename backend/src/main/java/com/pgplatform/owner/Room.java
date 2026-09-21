package com.pgplatform.owner;

import com.pgplatform.common.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;

@Getter
@Setter
@Entity
@Table(name = "rooms")
public class Room extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "floor_id", nullable = false)
    private Floor floor;

    @Column(name = "room_number", nullable = false)
    private String roomNumber;

    /** Number of beds this room holds. Changing this drives Bed auto-creation/removal -- see RoomService. */
    @Column(name = "sharing_count", nullable = false)
    private Integer sharingCount;

    @Column(name = "rent_per_bed", nullable = false, precision = 10, scale = 2)
    private BigDecimal rentPerBed;

    @Enumerated(EnumType.STRING)
    @Column(name = "room_type", nullable = false, length = 20)
    private RoomType roomType = RoomType.NON_AC;

    @Enumerated(EnumType.STRING)
    @Column(name = "booking_mode", nullable = false, length = 20)
    private RoomBookingMode bookingMode = RoomBookingMode.MONTHLY;

    @Column(name = "day_wise_rate", precision = 10, scale = 2)
    private BigDecimal dayWiseRate;

    @Column(name = "notice_period_days", nullable = false)
    private Integer noticePeriodDays = 15;

    @Column(name = "security_deposit", nullable = false, precision = 10, scale = 2)
    private BigDecimal securityDeposit = BigDecimal.ZERO;
}
