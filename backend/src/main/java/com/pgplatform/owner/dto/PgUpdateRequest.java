package com.pgplatform.owner.dto;

import com.pgplatform.owner.GenderPreference;
import com.pgplatform.owner.PgStatus;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record PgUpdateRequest(
        @NotBlank String name,
        @NotBlank String address,
        @NotBlank String city,
        String state,
        String pincode,
        Double latitude,
        Double longitude,
        String description,
        @NotNull GenderPreference genderPreference,
        @NotNull PgStatus status
) {
}
