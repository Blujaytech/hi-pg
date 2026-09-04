package com.pgplatform.auth;

import com.pgplatform.common.ConflictException;
import com.pgplatform.notification.NotificationGateway;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

@Service
public class PasswordResetService {

    private static final long TOKEN_TTL_MINUTES = 30;

    private final UserRepository userRepository;
    private final PasswordResetTokenRepository tokenRepository;
    private final JwtService jwtService;
    private final PasswordEncoder passwordEncoder;
    private final NotificationGateway notificationGateway;

    public PasswordResetService(UserRepository userRepository, PasswordResetTokenRepository tokenRepository,
                                 JwtService jwtService, PasswordEncoder passwordEncoder,
                                 NotificationGateway notificationGateway) {
        this.userRepository = userRepository;
        this.tokenRepository = tokenRepository;
        this.jwtService = jwtService;
        this.passwordEncoder = passwordEncoder;
        this.notificationGateway = notificationGateway;
    }

    @Transactional
    public void requestReset(String email) {
        // Deliberately do not reveal whether the email exists (avoids account enumeration).
        userRepository.findByEmailAndDeletedAtIsNull(email).ifPresent(user -> {
            String rawToken = jwtService.generateOpaqueToken();
            PasswordResetToken token = new PasswordResetToken();
            token.setUser(user);
            token.setTokenHash(jwtService.hash(rawToken));
            token.setExpiresAt(Instant.now().plus(TOKEN_TTL_MINUTES, ChronoUnit.MINUTES));
            tokenRepository.save(token);

            notificationGateway.sendEmail(user.getEmail(), "Reset your password",
                    "Use this token to reset your password (expires in " + TOKEN_TTL_MINUTES + " minutes): " + rawToken);
        });
    }

    @Transactional
    public void confirmReset(String rawToken, String newPassword) {
        PasswordResetToken token = tokenRepository.findByTokenHash(jwtService.hash(rawToken))
                .orElseThrow(() -> new ConflictException("Invalid or expired reset token"));

        if (!token.isValid()) {
            throw new ConflictException("Invalid or expired reset token");
        }

        User user = token.getUser();
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        userRepository.save(user);

        token.setConsumed(true);
        tokenRepository.save(token);
    }
}
