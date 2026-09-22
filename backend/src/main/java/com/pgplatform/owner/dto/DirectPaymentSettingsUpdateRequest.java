package com.pgplatform.owner.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record DirectPaymentSettingsUpdateRequest(
        boolean enabled,
        @NotBlank @Size(max = 255) String beneficiaryName,
        @NotBlank @Size(max = 320)
        @Pattern(regexp = "^[A-Za-z0-9._-]{2,256}@[A-Za-z0-9.-]{2,64}$", message = "must be a valid UPI ID")
        String upiId,
        @NotBlank @Pattern(regexp = "^\\+?[1-9][0-9]{9,14}$", message = "must be a valid mobile number")
        String mobileNumber
) {
}
