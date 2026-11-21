package com.pgplatform.jobs;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Map;
import java.util.Optional;

/**
 * Lets Cloud Scheduler trigger {@link BackgroundJob}s over HTTP so the Cloud
 * Run service can use request-based billing and scale to zero.
 *
 * <p>Not a user-facing API: it is outside JWT auth and instead requires the
 * shared secret {@code app.jobs.trigger-token} (Secret Manager-backed env var
 * {@code INTERNAL_JOBS_TOKEN}) in the {@code X-Job-Token} header. When no token
 * is configured the endpoint does not exist (404), so local/dev and any
 * environment that hasn't opted in expose nothing.
 */
@RestController
public class InternalJobController {

    static final String TOKEN_HEADER = "X-Job-Token";

    private final BackgroundJobRunner runner;
    private final byte[] expectedToken;

    public InternalJobController(BackgroundJobRunner runner,
                                 @Value("${app.jobs.trigger-token:}") String triggerToken) {
        this.runner = runner;
        this.expectedToken = triggerToken == null || triggerToken.isBlank()
                ? null
                : triggerToken.trim().getBytes(StandardCharsets.UTF_8);
    }

    @PostMapping("/api/v1/internal/jobs/{job}")
    public ResponseEntity<Map<String, Object>> trigger(@PathVariable("job") String jobSlug,
                                                       @RequestHeader(value = TOKEN_HEADER, required = false) String token) {
        if (expectedToken == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }
        if (token == null || !MessageDigest.isEqual(expectedToken, token.trim().getBytes(StandardCharsets.UTF_8))) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        Optional<BackgroundJob> job = BackgroundJob.fromSlug(jobSlug);
        if (job.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }
        long started = System.nanoTime();
        BackgroundJobRunner.Outcome outcome = runner.run(job.get());
        return ResponseEntity.ok(Map.of(
                "job", job.get().slug(),
                "outcome", outcome.name(),
                "durationMs", (System.nanoTime() - started) / 1_000_000));
    }
}
