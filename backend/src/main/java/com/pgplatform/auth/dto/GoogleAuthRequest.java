package com.pgplatform.auth.dto;

import jakarta.validation.constraints.NotBlank;

/** ID token returned by Google's native SDK and verified server-side. */
public record GoogleAuthRequest(@NotBlank String idToken) {
}
