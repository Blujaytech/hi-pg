package com.pgplatform.common.web;

import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class HealthControllerTest {

    private final HealthController controller = new HealthController();

    @Test
    void rootReturnsSafePublicServiceMetadata() {
        Map<String, Object> response = controller.index();

        assertThat(response)
                .containsEntry("service", "hi-pg-api")
                .containsEntry("status", "UP")
                .containsEntry("apiBasePath", "/api/v1")
                .containsEntry("health", "/actuator/health");
    }
}
