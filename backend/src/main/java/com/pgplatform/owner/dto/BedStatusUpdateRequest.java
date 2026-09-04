package com.pgplatform.owner.dto;

import com.pgplatform.owner.BedStatus;
import jakarta.validation.constraints.NotNull;

public record BedStatusUpdateRequest(@NotNull BedStatus status) {
}
