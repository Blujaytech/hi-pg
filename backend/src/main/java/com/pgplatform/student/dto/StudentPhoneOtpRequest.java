package com.pgplatform.student.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record StudentPhoneOtpRequest(
        @NotBlank @Pattern(regexp = "^\\+?[1-9][0-9]{9,14}$", message = "must be a valid mobile number") String phone
) {
}
