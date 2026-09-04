package com.pgplatform.notification;

import com.pgplatform.auth.User;
import com.pgplatform.auth.UserRepository;
import com.pgplatform.common.NotFoundException;
import com.pgplatform.notification.dto.DeviceTokenRegisterRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
public class DeviceTokenService {

    private final DeviceTokenRepository deviceTokenRepository;
    private final UserRepository userRepository;

    public DeviceTokenService(DeviceTokenRepository deviceTokenRepository, UserRepository userRepository) {
        this.deviceTokenRepository = deviceTokenRepository;
        this.userRepository = userRepository;
    }

    /**
     * Upsert by token: the same physical device re-registering (app
     * restart, token refresh) updates the existing row rather than piling
     * up duplicates -- and if that token previously belonged to a different
     * account on the same device (e.g. logged out, someone else logged in),
     * it's reassigned rather than left pointing at the wrong user.
     */
    @Transactional
    public void register(UUID userId, DeviceTokenRegisterRequest request) {
        User user = userRepository.findByIdAndDeletedAtIsNull(userId)
                .orElseThrow(() -> new NotFoundException("User not found"));

        DeviceToken deviceToken = deviceTokenRepository.findByTokenAndDeletedAtIsNull(request.token())
                .orElseGet(DeviceToken::new);
        deviceToken.setUser(user);
        deviceToken.setToken(request.token());
        deviceToken.setPlatform(request.platform());
        deviceTokenRepository.save(deviceToken);
    }

    /** Only removes the token if it belongs to the calling user -- silently no-ops otherwise (not a 403; a
     *  token that isn't yours or was already removed both look the same to the caller). */
    @Transactional
    public void unregister(UUID userId, String token) {
        deviceTokenRepository.findByTokenAndDeletedAtIsNull(token)
                .filter(dt -> dt.getUser().getId().equals(userId))
                .ifPresent(dt -> {
                    dt.markDeleted();
                    deviceTokenRepository.save(dt);
                });
    }
}
