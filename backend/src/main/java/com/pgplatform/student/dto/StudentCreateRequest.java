package com.pgplatform.student.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

import java.time.LocalDate;

public record StudentCreateRequest(
        @NotBlank String fullName,
        @NotBlank @Pattern(regexp = "^\\+?[1-9][0-9]{9,14}$", message = "phone must be a valid mobile number") String phone,
        String email,
        String guardianName,
        @Pattern(regexp = "^$|^\\+?[1-9][0-9]{9,14}$", message = "guardian phone must be a valid mobile number") String guardianPhone,
        String permanentAddress,
        String idProofNumber,
        @NotNull LocalDate dateOfJoining,
        /** Optional: assign straight into a bed at creation time. */
        String bedId
) {
}
