package com.pgplatform.auth;

import com.pgplatform.auth.dto.AuthResponse;
import com.pgplatform.auth.dto.OwnerLoginRequest;
import com.pgplatform.auth.dto.OwnerSignupRequest;
import com.pgplatform.common.ConflictException;
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

    public OwnerAuthService(UserRepository userRepository, PasswordEncoder passwordEncoder, TokenIssuer tokenIssuer) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.tokenIssuer = tokenIssuer;
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
                .filter(u -> u.getRole() == Role.OWNER)
                .orElseThrow(() -> new BadCredentialsException("Invalid credentials"));

        if (user.getPasswordHash() == null || !passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw new BadCredentialsException("Invalid credentials");
        }
        if (user.getStatus() == UserStatus.DISABLED) {
            throw new BadCredentialsException("Account disabled");
        }

        return tokenIssuer.issueFor(user);
    }

    private String normalizeEmail(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }
}
