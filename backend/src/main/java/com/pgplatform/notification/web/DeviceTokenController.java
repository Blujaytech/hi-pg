package com.pgplatform.notification.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.notification.DeviceTokenService;
import com.pgplatform.notification.dto.DeviceTokenRegisterRequest;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 * Available to any authenticated user (owner or student) -- both can
 * receive push notifications about their own activity. See
 * docs/decisions.md ADR-0020 for why no Flutter client wires this up to a
 * real FCM token yet.
 */
@RestController
public class DeviceTokenController {

    private final DeviceTokenService deviceTokenService;

    public DeviceTokenController(DeviceTokenService deviceTokenService) {
        this.deviceTokenService = deviceTokenService;
    }

    @PostMapping("/api/v1/me/device-tokens")
    public ResponseEntity<Void> register(@AuthenticationPrincipal UserPrincipal principal,
                                          @Valid @RequestBody DeviceTokenRegisterRequest request) {
        deviceTokenService.register(principal.getId(), request);
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/api/v1/me/device-tokens/{token}")
    public ResponseEntity<Void> unregister(@AuthenticationPrincipal UserPrincipal principal, @PathVariable String token) {
        deviceTokenService.unregister(principal.getId(), token);
        return ResponseEntity.noContent().build();
    }
}
