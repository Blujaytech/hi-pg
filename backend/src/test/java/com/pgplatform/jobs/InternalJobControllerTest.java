package com.pgplatform.jobs;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class InternalJobControllerTest {

    private final BackgroundJobRunner runner = mock(BackgroundJobRunner.class);

    @Test
    void endpointDoesNotExistWhenNoTokenIsConfigured() {
        InternalJobController controller = new InternalJobController(runner, "");

        ResponseEntity<Map<String, Object>> response = controller.trigger("booking-hold-expiry", "anything");

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        verifyNoInteractions(runner);
    }

    @Test
    void rejectsMissingToken() {
        InternalJobController controller = new InternalJobController(runner, "s3cret-token");

        ResponseEntity<Map<String, Object>> response = controller.trigger("booking-hold-expiry", null);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        verifyNoInteractions(runner);
    }

    @Test
    void rejectsWrongToken() {
        InternalJobController controller = new InternalJobController(runner, "s3cret-token");

        ResponseEntity<Map<String, Object>> response = controller.trigger("booking-hold-expiry", "s3cret-tokeX");

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        verifyNoInteractions(runner);
    }

    @Test
    void unknownJobIsNotFoundEvenWithValidToken() {
        InternalJobController controller = new InternalJobController(runner, "s3cret-token");

        ResponseEntity<Map<String, Object>> response = controller.trigger("drop-database", "s3cret-token");

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        verifyNoInteractions(runner);
    }

    @Test
    void runsTheNamedJobWithValidToken() {
        when(runner.run(any())).thenReturn(BackgroundJobRunner.Outcome.COMPLETED);
        InternalJobController controller = new InternalJobController(runner, "s3cret-token");

        ResponseEntity<Map<String, Object>> response = controller.trigger("fee-reminders", "s3cret-token");

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody())
                .containsEntry("job", "fee-reminders")
                .containsEntry("outcome", "COMPLETED");
        verify(runner).run(BackgroundJob.FEE_REMINDERS);
    }

    @Test
    void everyJobHasAUniqueResolvableSlug() {
        for (BackgroundJob job : BackgroundJob.values()) {
            assertThat(BackgroundJob.fromSlug(job.slug())).contains(job);
        }
    }
}
