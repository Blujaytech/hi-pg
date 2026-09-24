package com.pgplatform.owner.dto;

import com.pgplatform.owner.GenderPreference;
import com.pgplatform.owner.Pg;
import com.pgplatform.owner.PgStatus;
import com.pgplatform.owner.PaymentOnboardingStatus;

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
        String photoUrl,
        GenderPreference genderPreference,
        PgStatus status,
        PaymentOnboardingStatus paymentOnboardingStatus,
        Integer platformCommissionBps,
        Instant createdAt
) {
    public static PgResponse from(Pg pg) {
        return from(pg, null);
    }

    public static PgResponse from(Pg pg, String photoUrl) {
        return new PgResponse(
                pg.getId(), pg.getName(), pg.getAddress(), pg.getCity(), pg.getState(), pg.getPincode(),
                pg.getLatitude(), pg.getLongitude(), pg.getDescription(), photoUrl, pg.getGenderPreference(),
                pg.getStatus(), pg.getPaymentOnboardingStatus(), pg.getPlatformCommissionBps(), pg.getCreatedAt()
        );
    }
}
