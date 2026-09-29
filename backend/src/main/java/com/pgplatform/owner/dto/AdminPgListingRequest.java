package com.pgplatform.owner.dto;

import com.pgplatform.owner.GenderPreference;
import jakarta.validation.constraints.*;

public record AdminPgListingRequest(
        @NotBlank @Size(max = 255) String name,
        @NotBlank @Size(max = 120) String ownerName,
        @NotBlank @Size(max = 20) String ownerMobile,
        @NotBlank @Size(max = 500) String address,
        @NotBlank @Size(max = 120) String city,
        @Size(max = 120) String state,
        @Size(max = 12) String pincode,
        @NotNull @DecimalMin("-90.0") @DecimalMax("90.0") Double latitude,
        @NotNull @DecimalMin("-180.0") @DecimalMax("180.0") Double longitude,
        @Size(max = 3000) String description,
        @NotNull GenderPreference genderPreference
) { }
