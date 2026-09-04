package com.pgplatform.notification;

import org.springframework.stereotype.Component;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Phase 14 -- "extend the Phase 10 mechanism to complaints/payments-updated-
 * live" (technical plan, flagged as optional/cuttable for v1). Rather than
 * adding a bespoke SSE stream per event type, this piggybacks on the single
 * fan-out point Phase 13 already created: NotificationService.notifyUser
 * publishes here too, so every one of its four trigger points (booking
 * confirmed/cancelled, payment received, complaint resolved) gets a live
 * in-app echo for free, with no changes to BookingService/PaymentOrderService/
 * ComplaintService beyond what Phase 13 already did.
 *
 * Same in-memory, single-instance design as BedAvailabilityBroadcaster (see
 * ADR-0016) and the same caveat: this only works correctly behind one
 * backend instance. Unlike the public bed-availability stream, this one is
 * per-user and requires the normal JWT auth (a browser's native
 * EventSource can't set an Authorization header, so this is a Flutter/dio
 * consumer only for now -- see docs/decisions.md ADR-0021).
 */
@Component
public class UserEventBroadcaster {

    private static final Duration EMITTER_TIMEOUT = Duration.ofMinutes(30);

    private final Map<UUID, CopyOnWriteArrayList<SseEmitter>> emittersByUser = new ConcurrentHashMap<>();

    public SseEmitter subscribe(UUID userId) {
        SseEmitter emitter = new SseEmitter(EMITTER_TIMEOUT.toMillis());
        CopyOnWriteArrayList<SseEmitter> emitters = emittersByUser.computeIfAbsent(userId, id -> new CopyOnWriteArrayList<>());
        emitters.add(emitter);

        Runnable remove = () -> emitters.remove(emitter);
        emitter.onCompletion(remove);
        emitter.onTimeout(remove);
        emitter.onError(ex -> remove.run());
        return emitter;
    }

    public void publish(UUID userId, String title, String message) {
        CopyOnWriteArrayList<SseEmitter> emitters = emittersByUser.get(userId);
        if (emitters == null || emitters.isEmpty()) {
            return;
        }
        UserEvent event = new UserEvent(title, message, Instant.now());
        for (SseEmitter emitter : emitters) {
            try {
                emitter.send(SseEmitter.event().name("notification").data(event));
            } catch (IOException e) {
                emitter.complete();
                emitters.remove(emitter);
            }
        }
    }
}
