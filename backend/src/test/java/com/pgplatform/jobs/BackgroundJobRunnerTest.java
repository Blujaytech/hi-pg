package com.pgplatform.jobs;

import com.pgplatform.auth.AccountDeletionStorageCleanupService;
import com.pgplatform.billing.FeeReminderService;
import com.pgplatform.booking.BookingService;
import com.pgplatform.notification.EngagementNotificationService;
import com.pgplatform.payment.DirectPaymentService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.ObjectProvider;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class BackgroundJobRunnerTest {

    private final BookingService bookingService = mock(BookingService.class);
    private final DirectPaymentService directPaymentService = mock(DirectPaymentService.class);
    private final AccountDeletionStorageCleanupService cleanup = mock(AccountDeletionStorageCleanupService.class);
    private final FeeReminderService feeReminderService = mock(FeeReminderService.class);
    private final EngagementNotificationService engagement = mock(EngagementNotificationService.class);
    @SuppressWarnings("unchecked")
    private final ObjectProvider<EngagementNotificationService> engagementProvider = mock(ObjectProvider.class);

    private final BackgroundJobRunner runner = new BackgroundJobRunner(
            bookingService, directPaymentService, cleanup, feeReminderService, engagementProvider);

    @Test
    void eachJobInvokesItsService() {
        when(engagementProvider.getIfAvailable()).thenReturn(engagement);

        for (BackgroundJob job : BackgroundJob.values()) {
            assertThat(runner.run(job)).isEqualTo(BackgroundJobRunner.Outcome.COMPLETED);
        }

        verify(bookingService).expirePaymentHolds();
        verify(bookingService).transitionDueStays();
        verify(directPaymentService).markOverdueReviews();
        verify(cleanup).retryPending();
        verify(feeReminderService).sendScheduledReminders();
        verify(engagement).sendScheduledEngagements();
    }

    @Test
    void engagementJobIsSkippedWhenFeatureIsDisabled() {
        when(engagementProvider.getIfAvailable()).thenReturn(null);

        assertThat(runner.run(BackgroundJob.ENGAGEMENT_NOTIFICATIONS))
                .isEqualTo(BackgroundJobRunner.Outcome.SKIPPED);
    }
}
