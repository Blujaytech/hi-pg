package com.pgplatform.auth.dto;

import jakarta.validation.constraints.NotBlank;

/** idToken as returned by Google's client-side SDK; verified server-side against Google's tokeninfo/JWKS. Stubbed for now -- see docs/decisions.md. */
public record GoogleAuthRequest(@NotBlank String idToken, String roleHint) {
}
