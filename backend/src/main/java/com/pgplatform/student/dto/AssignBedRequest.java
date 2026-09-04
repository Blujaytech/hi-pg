package com.pgplatform.student.dto;

import jakarta.validation.constraints.NotBlank;

public record AssignBedRequest(@NotBlank String bedId) {
}
