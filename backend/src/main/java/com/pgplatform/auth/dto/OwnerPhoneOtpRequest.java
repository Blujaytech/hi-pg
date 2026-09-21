package com.pgplatform.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record OwnerPhoneOtpRequest(
        @NotBlank @Pattern(regexp = "^\\+?[0-9]{10,15}$", message = "Enter a valid phone number") String phone
) {
}
