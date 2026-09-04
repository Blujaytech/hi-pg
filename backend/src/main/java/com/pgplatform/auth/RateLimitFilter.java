package com.pgplatform.auth;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.pgplatform.common.ApiError;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Phase 15 security audit finding (technical plan §7 item 7: "Rate limiting
 * / abuse prevention ... isn't in the original requirements -- recommend
 * adding"). {@code OtpService} already caps OTP requests per phone number,
 * but nothing capped requests per *caller* -- an attacker with a single IP
 * could still brute-force {@code /auth/owner/login} passwords, hammer
 * {@code /auth/owner/password-reset/request} (email-enumeration timing, or
 * just spam), or cycle through many phone numbers to run up SMS costs
 * despite the per-phone cap. This filter closes that gap with a simple
 * fixed-window counter per (client IP, path prefix), applied only to the
 * unauthenticated {@code /api/v1/auth/**} endpoints -- everywhere else is
 * already behind JWT auth, where abuse is attributable to a specific
 * account rather than an anonymous IP.
 *
 * <p><b>Same single-instance caveat as {@code BedAvailabilityBroadcaster}
 * (ADR-0016) and {@code UserEventBroadcaster} (ADR-0021)</b>: the counters
 * are an in-memory {@link ConcurrentHashMap}, per backend instance. Behind
 * a load balancer with multiple instances, an attacker could get roughly
 * {@code instanceCount x limit} requests through before every instance's
 * window independently trips -- not a bypass, just a weaker limit than the
 * configured one. Revisit with a shared store (Redis, or a Postgres table)
 * if this backend is ever scaled horizontally, same as those two ADRs
 * flag for their own in-memory registries. See docs/decisions.md ADR-0022.
 */
@Component
public class RateLimitFilter extends OncePerRequestFilter {

    private record Window(long windowStartEpochSeconds, AtomicInteger count) {
    }

    private final Map<String, Window> windows = new ConcurrentHashMap<>();
    private final ObjectMapper objectMapper;

    @Value("${app.rate-limit.auth.window-seconds:60}")
    private long windowSeconds;

    @Value("${app.rate-limit.auth.max-requests:20}")
    private int maxRequestsPerWindow;

    public RateLimitFilter(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request,
                                     @NonNull HttpServletResponse response,
                                     @NonNull FilterChain filterChain) throws ServletException, IOException {
        String path = request.getRequestURI();
        if (!path.startsWith("/api/v1/auth/")) {
            filterChain.doFilter(request, response);
            return;
        }

        String key = clientIp(request) + "|" + path;
        long nowSeconds = Instant.now().getEpochSecond();
        long currentWindowStart = nowSeconds - (nowSeconds % windowSeconds);

        Window window = windows.compute(key, (k, existing) -> {
            if (existing == null || existing.windowStartEpochSeconds() != currentWindowStart) {
                return new Window(currentWindowStart, new AtomicInteger(0));
            }
            return existing;
        });

        int requestsSoFar = window.count().incrementAndGet();
        if (requestsSoFar > maxRequestsPerWindow) {
            response.setStatus(429);
            response.setContentType("application/json");
            ApiError error = ApiError.of(429, "TOO_MANY_REQUESTS",
                    "Too many requests. Try again in a minute.", path);
            response.getWriter().write(objectMapper.writeValueAsString(error));
            return;
        }

        // Opportunistic cleanup so this map doesn't grow unbounded under a very wide spread of
        // IPs/paths -- cheap relative to a real scheduled sweep, good enough at pilot scale.
        if (windows.size() > 10_000) {
            windows.entrySet().removeIf(e -> e.getValue().windowStartEpochSeconds() != currentWindowStart);
        }

        filterChain.doFilter(request, response);
    }

    /**
     * Trusts {@code X-Forwarded-For} for the client IP. That is only safe when this backend
     * sits behind a reverse proxy/load balancer that sets (and overwrites, never appends-to-
     * client-supplied) this header -- see docs/security.md. Deployed with nothing in front of
     * it, a caller could set an arbitrary X-Forwarded-For per request and get a fresh bucket
     * every time, defeating the limiter entirely. Phase 16 (pilot deployment) must confirm the
     * chosen reverse proxy is configured this way before this filter can be relied on.
     */
    private String clientIp(HttpServletRequest request) {
        String forwardedFor = request.getHeader("X-Forwarded-For");
        if (forwardedFor != null && !forwardedFor.isBlank()) {
            return forwardedFor.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
