package com.pgplatform.auth;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;
import com.google.firebase.auth.FirebaseToken;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

@Component
public class FirebasePhoneIdentityVerifier {

    private final ObjectProvider<FirebaseAuth> firebaseAuth;

    public FirebasePhoneIdentityVerifier(ObjectProvider<FirebaseAuth> firebaseAuth) {
        this.firebaseAuth = firebaseAuth;
    }

    public FirebasePhoneIdentity verify(String idToken) {
        FirebaseAuth auth = firebaseAuth.getIfAvailable();
        if (auth == null) {
            throw new UnsupportedOperationException("Firebase phone authentication is not configured");
        }
        try {
            FirebaseToken token = auth.verifyIdToken(idToken, true);
            Object phoneClaim = token.getClaims().get("phone_number");
            String phone = phoneClaim instanceof String ? (String) phoneClaim : null;
            if (!StringUtils.hasText(phone)) {
                throw new BadCredentialsException("Firebase token has no verified phone number");
            }
            return new FirebasePhoneIdentity(token.getUid(), phone);
        } catch (FirebaseAuthException exception) {
            throw new BadCredentialsException("Invalid Firebase identity token", exception);
        }
    }
}
