package com.pgplatform.common.web;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.Map;

@RestController
public class HealthController {

    @GetMapping("/")
    public Map<String, Object> index() {
        return Map.of(
                "service", "hi-pg-api",
                "status", "UP",
                "apiBasePath", "/api/v1",
                "health", "/actuator/health"
        );
    }

    @GetMapping("/api/v1/health")
    public Map<String, Object> health() {
        return Map.of(
                "status", "UP",
                "service", "pg-platform-backend",
                "timestamp", Instant.now().toString()
        );
    }
}
