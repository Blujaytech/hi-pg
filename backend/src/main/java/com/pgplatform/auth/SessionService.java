package com.pgplatform.auth;

import com.pgplatform.auth.dto.AuthResponse;
import com.pgplatform.common.ForbiddenException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Refresh-token rotation and logout. Rotation: every /refresh call issues a brand new refresh token and revokes the old one. */
@Service
public class SessionService {

    private final RefreshTokenRepository refreshTokenRepository;
    private final UserRepository userRepository;
    private final JwtService jwtService;
    private final TokenIssuer tokenIssuer;

    public SessionService(RefreshTokenRepository refreshTokenRepository, UserRepository userRepository,
                           JwtService jwtService, TokenIssuer tokenIssuer) {
        this.refreshTokenRepository = refreshTokenRepository;
        this.userRepository = userRepository;
        this.jwtService = jwtService;
        this.tokenIssuer = tokenIssuer;
    }

    @Transactional
    public AuthResponse refresh(String rawRefreshToken) {
        String hash = jwtService.hash(rawRefreshToken);
        RefreshToken stored = refreshTokenRepository.findByTokenHash(hash)
                .orElseThrow(() -> new BadCredentialsException("Invalid refresh token"));

        if (!stored.isValid()) {
            throw new BadCredentialsException("Refresh token expired or revoked");
        }

        User user = userRepository.findByIdAndDeletedAtIsNull(stored.getUser().getId())
                .orElseThrow(() -> new ForbiddenException("Account no longer exists"));

        stored.setRevoked(true);
        refreshTokenRepository.save(stored);

        return tokenIssuer.issueFor(user);
    }

    @Transactional
    public void logout(String rawRefreshToken) {
        String hash = jwtService.hash(rawRefreshToken);
        refreshTokenRepository.findByTokenHash(hash).ifPresent(rt -> {
            rt.setRevoked(true);
            refreshTokenRepository.save(rt);
        });
    }
}
