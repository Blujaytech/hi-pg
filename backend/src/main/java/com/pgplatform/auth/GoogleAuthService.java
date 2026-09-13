package com.pgplatform.auth;

import com.pgplatform.auth.dto.AuthResponse;
import com.pgplatform.auth.dto.GoogleAuthRequest;
import com.pgplatform.common.ConflictException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Student-only Google sign-in. Owners continue to authenticate exclusively
 * through the existing email/password endpoints.
 */
@Service
public class GoogleAuthService {

    private final GoogleIdentityVerifier identityVerifier;
    private final UserRepository userRepository;
    private final TokenIssuer tokenIssuer;

    public GoogleAuthService(GoogleIdentityVerifier identityVerifier, UserRepository userRepository,
                             TokenIssuer tokenIssuer) {
        this.identityVerifier = identityVerifier;
        this.userRepository = userRepository;
        this.tokenIssuer = tokenIssuer;
    }

    @Transactional
    public AuthResponse authenticate(GoogleAuthRequest request) {
        GoogleIdentity identity = identityVerifier.verify(request.idToken());
        User user = userRepository.findByGoogleSubjectAndDeletedAtIsNull(identity.subject())
                .orElseGet(() -> findOrCreateStudent(identity));

        if (user.getRole() != Role.STUDENT) {
            throw new ConflictException("This Google account belongs to a PG owner. Use owner login instead.");
        }
        if (user.getStatus() == UserStatus.DISABLED) {
            throw new BadCredentialsException("Account disabled");
        }

        return tokenIssuer.issueFor(user);
    }

    private User findOrCreateStudent(GoogleIdentity identity) {
        return userRepository.findByEmailIgnoreCaseAndDeletedAtIsNull(identity.email())
                .map(existing -> linkExistingStudent(existing, identity))
                .orElseGet(() -> createStudent(identity));
    }

    private User linkExistingStudent(User user, GoogleIdentity identity) {
        if (user.getRole() != Role.STUDENT) {
            throw new ConflictException("This Google email belongs to a PG owner. Use owner login instead.");
        }
        if (user.getGoogleSubject() != null && !user.getGoogleSubject().equals(identity.subject())) {
            throw new ConflictException("This email is already linked to another Google account.");
        }

        user.setGoogleSubject(identity.subject());
        user.setProvider(AuthProviderType.GOOGLE);
        user.setEmailVerified(true);
        return userRepository.save(user);
    }

    private User createStudent(GoogleIdentity identity) {
        User user = new User();
        user.setEmail(identity.email());
        user.setFullName(identity.fullName());
        user.setRole(Role.STUDENT);
        user.setProvider(AuthProviderType.GOOGLE);
        user.setGoogleSubject(identity.subject());
        user.setEmailVerified(true);
        return userRepository.save(user);
    }
}
