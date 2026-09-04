package com.pgplatform.notification.dto;

import com.pgplatform.notification.DevicePlatform;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record DeviceTokenRegisterRequest(@NotBlank String token, @NotNull DevicePlatform platform) {
}
