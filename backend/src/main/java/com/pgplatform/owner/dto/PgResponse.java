package com.pgplatform.owner.dto;

import com.pgplatform.owner.GenderPreference;
import com.pgplatform.owner.Pg;
import com.pgplatform.owner.PgStatus;

import java.time.Instant;
import java.util.UUID;

public record PgResponse(
        UUID id,
        String name,
        String address,
        String city,
        String state,
        String pincode,
        Double latitude,
        Double longitude,
        String description,
        GenderPreference genderPreference,
        PgStatus status,
        Instant createdAt
) {
    public static PgResponse from(Pg pg) {
        return new PgResponse(
                pg.getId(), pg.getName(), pg.getAddress(), pg.getCity(), pg.getState(), pg.getPincode(),
                pg.getLatitude(), pg.getLongitude(), pg.getDescription(), pg.getGenderPreference(),
                pg.getStatus(), pg.getCreatedAt()
        );
    }
}
