package com.pgplatform.discovery;

import com.pgplatform.AbstractIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatNoException;

/**
 * Light smoke test -- a full SSE round trip needs a real HTTP connection
 * (MockMvc async / WebTestClient), which is disproportionate for what this
 * class does. What actually matters structurally is proven elsewhere: every
 * bed-status-mutating integration test (StudentBedAssignmentTest,
 * RoomBedAutoCreationTest, etc.) already boots the full Spring context with
 * this bean wired into BedService/RoomService/StudentService -- if that
 * wiring were broken, those tests would fail to even start.
 */
class BedAvailabilityBroadcasterTest extends AbstractIntegrationTest {

    @Autowired
    private BedAvailabilityBroadcaster broadcaster;

    @Test
    void subscribingAndNotifyingNeverThrowsEvenWithNoRoomsOrNoSubscribers() {
        UUID pgId = UUID.randomUUID();

        assertThatNoException().isThrownBy(() -> broadcaster.notifyChanged(pgId)); // no subscribers yet -- no-op

        SseEmitter emitter = broadcaster.subscribe(pgId);
        assertThatCode(() -> {
            broadcaster.notifyChanged(pgId);
            broadcaster.heartbeat();
        }).doesNotThrowAnyException();

        emitter.complete();
    }
}
