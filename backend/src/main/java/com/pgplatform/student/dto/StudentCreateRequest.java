package com.pgplatform.student.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

public record StudentCreateRequest(
        @NotBlank String fullName,
        @NotBlank String phone,
        String email,
        String guardianName,
        String guardianPhone,
        String permanentAddress,
        String idProofNumber,
        @NotNull LocalDate dateOfJoining,
        /** Optional: assign straight into a bed at creation time. */
        String bedId
) {
}
