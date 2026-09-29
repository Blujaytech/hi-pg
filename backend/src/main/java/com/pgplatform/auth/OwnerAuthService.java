package com.pgplatform.auth;

import com.pgplatform.auth.dto.AuthResponse;
import com.pgplatform.auth.dto.OwnerLoginRequest;
import com.pgplatform.auth.dto.OwnerSignupRequest;
import com.pgplatform.common.ConflictException;
import com.pgplatform.owner.PgClaimService;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Locale;

@Service
public class OwnerAuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final TokenIssuer tokenIssuer;
    private final FirebasePhoneIdentityVerifier firebaseIdentityVerifier;
    private final PgClaimService pgClaimService;

    public OwnerAuthService(UserRepository userRepository, PasswordEncoder passwordEncoder, TokenIssuer tokenIssuer,
                            FirebasePhoneIdentityVerifier firebaseIdentityVerifier, PgClaimService pgClaimService) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.tokenIssuer = tokenIssuer;
        this.firebaseIdentityVerifier = firebaseIdentityVerifier;
        this.pgClaimService = pgClaimService;
    }

    @Transactional
    public AuthResponse signup(OwnerSignupRequest request) {
        String normalizedEmail = normalizeEmail(request.email());
        if (userRepository.existsByEmailIgnoreCaseAndDeletedAtIsNull(normalizedEmail)) {
            throw new ConflictException("An account with this email already exists");
        }
        if (request.phone() != null && userRepository.existsByPhoneAndDeletedAtIsNull(request.phone())) {
            throw new ConflictException("An account with this phone number already exists");
        }

        User user = new User();
        user.setFullName(request.fullName());
        user.setEmail(normalizedEmail);
        user.setPhone(request.phone());
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setRole(Role.OWNER);
        user.setProvider(AuthProviderType.LOCAL);

        userRepository.save(user);
        return tokenIssuer.issueFor(user);
    }

    @Transactional
    public AuthResponse login(OwnerLoginRequest request) {
        User user = userRepository.findByEmailIgnoreCaseAndDeletedAtIsNull(normalizeEmail(request.email()))
                // Owners and platform administrators deliberately share one
                // email/password entry point. The authenticated server role,
                // never an email check in the client, decides the workspace.
                .filter(u -> u.getRole() == Role.OWNER || u.getRole() == Role.ADMIN)
                .orElseThrow(() -> new BadCredentialsException("Invalid credentials"));

        if (user.getPasswordHash() == null || !passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw new BadCredentialsException("Invalid credentials");
        }
        if (user.getStatus() == UserStatus.DISABLED) {
            throw new BadCredentialsException("Account disabled");
        }

        return tokenIssuer.issueFor(user);
    }

    @Transactional
    public AuthResponse authenticateFirebasePhone(String idToken, String fullName) {
        FirebasePhoneIdentity identity = firebaseIdentityVerifier.verify(idToken);
        String phone = PhoneNumbers.normalize(identity.phone());
        User user = findExistingPhoneUser(phone).orElseGet(() -> createInvitedOwner(phone, fullName));
        if (user.getRole() != Role.OWNER) {
            throw new ConflictException("This mobile belongs to a customer account. Contact support to use it for ownership.");
        }
        if (user.getStatus() == UserStatus.DISABLED) {
            throw new BadCredentialsException("Account disabled");
        }
        user.setPhone(phone);
        user.setPhoneVerified(true);
        userRepository.save(user);
        return tokenIssuer.issueFor(user);
    }

    private java.util.Optional<User> findExistingPhoneUser(String phone) {
        java.util.Optional<User> exact = userRepository.findByPhoneAndDeletedAtIsNull(phone);
        if (exact.isPresent()) return exact;
        return phone.startsWith("+91") && phone.length() == 13
                ? userRepository.findByPhoneAndDeletedAtIsNull(phone.substring(3))
                : java.util.Optional.empty();
    }

    private User createInvitedOwner(String phone, String fullName) {
        if (!pgClaimService.hasInvitation(phone)) {
            throw new ConflictException("No PG invitation was found for this mobile number");
        }
        User user = new User();
        user.setPhone(phone);
        user.setFullName(fullName == null || fullName.isBlank() ? "PG owner" : fullName.trim());
        user.setRole(Role.OWNER);
        user.setProvider(AuthProviderType.LOCAL);
        user.setPhoneVerified(true);
        return user;
    }

    private String normalizeEmail(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }
}
