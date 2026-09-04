package com.pgplatform.discovery;

import com.pgplatform.discovery.dto.BedAvailabilityEvent;
import com.pgplatform.owner.BedRepository;
import com.pgplatform.owner.BedStatus;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Phase 10 -- Live Bed Availability. Chosen mechanism: Server-Sent Events
 * (one-way server-to-client push), not WebSocket and not client polling --
 * see docs/decisions.md for why. Holds one {@link SseEmitter} per connected
 * client, grouped by the PG they're watching; every owner-side action that
 * flips a Bed's status (assign/reassign/move-out/manual status change,
 * room sharing-count changes) calls {@link #notifyChanged(UUID)} at the end
 * of its transaction so subscribers see the *new*, already-committed state.
 */
@Component
public class BedAvailabilityBroadcaster {

    private static final Logger log = LoggerFactory.getLogger(BedAvailabilityBroadcaster.class);
    private static final Duration EMITTER_TIMEOUT = Duration.ofMinutes(30);

    private final Map<UUID, CopyOnWriteArrayList<SseEmitter>> emittersByPg = new ConcurrentHashMap<>();
    private final BedRepository bedRepository;

    public BedAvailabilityBroadcaster(BedRepository bedRepository) {
        this.bedRepository = bedRepository;
    }

    public SseEmitter subscribe(UUID pgId) {
        SseEmitter emitter = new SseEmitter(EMITTER_TIMEOUT.toMillis());
        CopyOnWriteArrayList<SseEmitter> emitters = emittersByPg.computeIfAbsent(pgId, id -> new CopyOnWriteArrayList<>());
        emitters.add(emitter);

        Runnable remove = () -> emitters.remove(emitter);
        emitter.onCompletion(remove);
        emitter.onTimeout(remove);
        emitter.onError(ex -> remove.run());

        try {
            emitter.send(SseEmitter.event().name("availability").data(currentSnapshot(pgId)));
        } catch (IOException e) {
            emitter.completeWithError(e);
        }
        return emitter;
    }

    /** Called at the end of any transaction that changes a bed's status for this PG. */
    public void notifyChanged(UUID pgId) {
        List<SseEmitter> emitters = emittersByPg.get(pgId);
        if (emitters == null || emitters.isEmpty()) {
            return;
        }
        BedAvailabilityEvent event = currentSnapshot(pgId);
        for (SseEmitter emitter : emitters) {
            try {
                emitter.send(SseEmitter.event().name("availability").data(event));
            } catch (IOException e) {
                emitter.complete();
                emitters.remove(emitter);
            }
        }
    }

    /** Keeps connections alive through proxies/load balancers that close idle HTTP connections. */
    @Scheduled(fixedRate = 25_000)
    public void heartbeat() {
        emittersByPg.forEach((pgId, emitters) -> {
            for (SseEmitter emitter : emitters) {
                try {
                    emitter.send(SseEmitter.event().comment("keep-alive"));
                } catch (IOException e) {
                    emitter.complete();
                    emitters.remove(emitter);
                    log.debug("Dropped stale SSE subscriber for pg {}", pgId);
                }
            }
        });
    }

    private BedAvailabilityEvent currentSnapshot(UUID pgId) {
        long total = bedRepository.countByPgId(pgId);
        long available = bedRepository.countByPgIdAndStatus(pgId, BedStatus.AVAILABLE);
        return new BedAvailabilityEvent(pgId, total, available);
    }
}
