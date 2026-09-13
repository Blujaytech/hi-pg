package com.pgplatform.auth;

/** Boundary around Google's ID-token verifier so auth behavior is testable offline. */
public interface GoogleIdentityVerifier {
    GoogleIdentity verify(String idToken);
}
