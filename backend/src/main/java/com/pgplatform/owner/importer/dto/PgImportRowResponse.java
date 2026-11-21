package com.pgplatform.owner.importer.dto;

import com.pgplatform.owner.GenderPreference;
import com.pgplatform.owner.PgInvitationStatus;
import com.pgplatform.owner.importer.PgImportPublishStatus;
import com.pgplatform.owner.importer.PgImportValidationStatus;

import java.util.List;
import java.util.UUID;

public record PgImportRowResponse(
        UUID id,
        int sourceRowNumber,
        String name,
        String ownerName,
        String ownerMobile,
        String address,
        String city,
        String state,
        String pincode,
        Double latitude,
        Double longitude,
        String locationUrl,
        String properLocality,
        String originalStayType,
        GenderPreference genderPreference,
        int imageCount,
        PgImportValidationStatus validationStatus,
        List<String> validationMessages,
        PgImportPublishStatus publishStatus,
        PgInvitationStatus invitationStatus,
        UUID publishedPgId
) { }
