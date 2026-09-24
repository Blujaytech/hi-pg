package com.pgplatform.student.dto;

import com.pgplatform.student.Student;
import com.pgplatform.student.StudentStatus;
import com.pgplatform.booking.Booking;
import com.pgplatform.booking.BookingStatus;
import com.pgplatform.booking.BookingType;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.UUID;

public record StudentResponse(
        UUID id,
        UUID pgId,
        UUID bedId,
        String bedLabel,
        String roomNumber,
        UUID bookingId,
        BookingStatus bookingStatus,
        BookingType bookingType,
        LocalDate checkOutDate,
        LocalTime checkOutTime,
        LocalDate plannedMoveOutDate,
        Integer noticeShortfallDays,
        boolean selfBooked,
        String fullName,
        String phone,
        String email,
        String guardianName,
        String guardianPhone,
        String permanentAddress,
        String idProofNumber,
        LocalDate dateOfJoining,
        StudentStatus status,
        LocalDate moveOutDate
) {
    public static StudentResponse from(Student student) {
        return from(student, null);
    }

    public static StudentResponse from(Student student, Booking booking) {
        var selectedBed = student.getBed() != null ? student.getBed()
                : booking == null ? null : booking.getBed();
        return new StudentResponse(
                student.getId(),
                student.getPg().getId(),
                selectedBed != null ? selectedBed.getId() : null,
                selectedBed != null ? selectedBed.getLabel() : null,
                selectedBed != null ? selectedBed.getRoom().getRoomNumber() : null,
                booking == null ? null : booking.getId(),
                booking == null ? null : booking.getStatus(),
                booking == null ? null : booking.getBookingType(),
                booking == null ? null : booking.getCheckOutDate(),
                booking == null ? null : booking.getCheckOutTime(),
                booking == null ? null : booking.getPlannedMoveOutDate(),
                booking == null ? 0 : booking.getNoticeShortfallDays(),
                student.getUser() != null,
                student.getFullName(),
                student.getPhone(),
                student.getEmail(),
                student.getGuardianName(),
                student.getGuardianPhone(),
                student.getPermanentAddress(),
                student.getIdProofNumber(),
                student.getDateOfJoining(),
                student.getStatus(),
                student.getMoveOutDate()
        );
    }
}
