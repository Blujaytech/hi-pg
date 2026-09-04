package com.pgplatform.notification;

import org.junit.jupiter.api.Test;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThatNoException;

/** Same smoke-test scope as BedAvailabilityBroadcasterTest -- see that class's javadoc for why. */
class UserEventBroadcasterTest {

    private final UserEventBroadcaster broadcaster = new UserEventBroadcaster();

    @Test
    void publishingWithNoSubscribersIsANoOpAndSubscribingThenPublishingNeverThrows() {
        UUID userId = UUID.randomUUID();

        assertThatNoException().isThrownBy(() -> broadcaster.publish(userId, "Title", "Message"));

        SseEmitter emitter = broadcaster.subscribe(userId);
        assertThatNoException().isThrownBy(() -> broadcaster.publish(userId, "Title", "Message"));
        emitter.complete();
    }
}
