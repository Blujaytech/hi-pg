package com.pgplatform.notification.web;

import com.pgplatform.auth.UserPrincipal;
import com.pgplatform.notification.UserEventBroadcaster;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

/**
 * Phase 14. Authenticated like any other endpoint (normal JWT bearer
 * token) -- unlike the public bed-availability stream (Phase 10), this
 * carries private per-user data, so it deliberately does NOT sit under
 * `/api/v1/public/**`. A plain browser `EventSource` can't attach an
 * Authorization header, so this is a Flutter/dio consumer only for now --
 * see docs/decisions.md ADR-0021.
 */
@RestController
public class UserEventStreamController {

    private final UserEventBroadcaster broadcaster;

    public UserEventStreamController(UserEventBroadcaster broadcaster) {
        this.broadcaster = broadcaster;
    }

    @GetMapping("/api/v1/me/events/stream")
    public SseEmitter stream(@AuthenticationPrincipal UserPrincipal principal) {
        return broadcaster.subscribe(principal.getId());
    }
}
