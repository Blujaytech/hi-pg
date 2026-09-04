package com.pgplatform.discovery.dto;

import com.pgplatform.owner.GenderPreference;

import java.math.BigDecimal;
import java.util.UUID;

public record PgSearchResultResponse(
        UUID id,
        String name,
        String city,
        String address,
        String description,
        GenderPreference genderPreference,
        Double latitude,
        Double longitude,
        long availableBeds,
        BigDecimal minRentPerBed,
        BigDecimal maxRentPerBed
) {
}
