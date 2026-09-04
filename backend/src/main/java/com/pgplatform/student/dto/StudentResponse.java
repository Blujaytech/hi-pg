package com.pgplatform.student.dto;

import com.pgplatform.student.Student;
import com.pgplatform.student.StudentStatus;

import java.time.LocalDate;
import java.util.UUID;

public record StudentResponse(
        UUID id,
        UUID pgId,
        UUID bedId,
        String bedLabel,
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
        return new StudentResponse(
                student.getId(),
                student.getPg().getId(),
                student.getBed() != null ? student.getBed().getId() : null,
                student.getBed() != null ? student.getBed().getLabel() : null,
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
