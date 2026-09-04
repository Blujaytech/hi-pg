package com.pgplatform.auth;

import com.pgplatform.auth.dto.AuthResponse;
import com.pgplatform.auth.dto.GoogleAuthRequest;
import org.springframework.stereotype.Service;

/**
 * STUB. Google OAuth is confirmed in the stack (§3 of the technical plan) but
 * not implemented yet: verifying an idToken needs Google's tokeninfo endpoint
 * or the google-api-client library plus a configured OAuth client ID/secret,
 * which are not provisioned. Wire this up in a dedicated feature/google-oauth
 * branch: verify idToken -> extract email+name+sub -> find-or-create User with
 * provider=GOOGLE -> tokenIssuer.issueFor(user). Left as a named stub instead
 * of silently absent so the API surface exists for mobile/web to build the
 * button against. See docs/decisions.md.
 */
@Service
public class GoogleAuthService {

    public AuthResponse authenticate(GoogleAuthRequest request) {
        throw new UnsupportedOperationException(
                "Google OAuth is not implemented yet. See GoogleAuthService and docs/decisions.md.");
    }
}
