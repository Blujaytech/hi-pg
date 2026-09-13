package com.pgplatform.auth;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.googleapis.javanet.GoogleNetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.security.GeneralSecurityException;
import java.util.List;
import java.util.Locale;

/** Production verifier backed by Google's rotating public signing keys. */
@Component
public class GoogleApiIdentityVerifier implements GoogleIdentityVerifier {

    private final GoogleIdTokenVerifier verifier;

    public GoogleApiIdentityVerifier(@Value("${app.google.oauth-client-id:}") String clientId) {
        String normalizedClientId = clientId == null ? "" : clientId.trim();
        if (normalizedClientId.isBlank()) {
            this.verifier = null;
            return;
        }

        try {
            this.verifier = new GoogleIdTokenVerifier.Builder(
                    GoogleNetHttpTransport.newTrustedTransport(),
                    GsonFactory.getDefaultInstance())
                    .setAudience(List.of(normalizedClientId))
                    .build();
        } catch (GeneralSecurityException | IOException exception) {
            throw new IllegalStateException("Google token verification could not be initialized", exception);
        }
    }

    @Override
    public GoogleIdentity verify(String idToken) {
        if (verifier == null) {
            throw new UnsupportedOperationException("Google student sign-in is not configured on this server.");
        }

        try {
            GoogleIdToken verifiedToken = verifier.verify(idToken);
            if (verifiedToken == null) {
                throw invalidToken();
            }

            GoogleIdToken.Payload payload = verifiedToken.getPayload();
            String subject = payload.getSubject();
            String email = payload.getEmail();
            if (subject == null || subject.isBlank() || email == null || email.isBlank()
                    || !Boolean.TRUE.equals(payload.getEmailVerified())) {
                throw invalidToken();
            }

            String normalizedEmail = email.trim().toLowerCase(Locale.ROOT);
            Object nameClaim = payload.get("name");
            int atIndex = normalizedEmail.indexOf('@');
            String fullName = nameClaim instanceof String name && !name.isBlank()
                    ? name.trim()
                    : atIndex > 0 ? normalizedEmail.substring(0, atIndex) : "Student";
            return new GoogleIdentity(subject, normalizedEmail, fullName);
        } catch (GeneralSecurityException exception) {
            throw invalidToken(exception);
        } catch (IOException exception) {
            throw new IllegalStateException("Google sign-in verification is temporarily unavailable", exception);
        }
    }

    private BadCredentialsException invalidToken() {
        return new BadCredentialsException("Invalid Google ID token");
    }

    private BadCredentialsException invalidToken(Exception cause) {
        return new BadCredentialsException("Invalid Google ID token", cause);
    }
}
