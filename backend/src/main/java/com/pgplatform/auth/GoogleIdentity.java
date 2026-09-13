package com.pgplatform.auth;

/** Trusted identity claims extracted only after Google has verified the token. */
public record GoogleIdentity(String subject, String email, String fullName) {
}
