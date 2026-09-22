package com.pgplatform.owner.dto;

import com.pgplatform.owner.PgDirectPaymentSettings;
import com.pgplatform.owner.Pg;

import java.time.Instant;
import java.util.UUID;

public record DirectPaymentSettingsResponse(
        UUID pgId,
        boolean enabled,
        String beneficiaryName,
        String upiId,
        String mobileNumber,
        boolean verified,
        Instant verifiedAt
) {
    public static DirectPaymentSettingsResponse from(PgDirectPaymentSettings settings) {
        return new DirectPaymentSettingsResponse(settings.getPg().getId(), settings.isEnabled(),
                settings.getBeneficiaryName(), settings.getUpiId(), settings.getMobileNumber(),
                settings.isVerified(), settings.getVerifiedAt());
    }

    public static DirectPaymentSettingsResponse unconfigured(Pg pg) {
        return new DirectPaymentSettingsResponse(pg.getId(), false,
                pg.getOwner().getFullName(), "",
                pg.getOwner().getPhone() == null ? "" : pg.getOwner().getPhone(),
                false, null);
    }
}
