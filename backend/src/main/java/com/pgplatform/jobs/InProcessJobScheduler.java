package com.pgplatform.jobs;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Default timer for {@link BackgroundJob}s: runs them inside the JVM with
 * Spring's scheduler. Only correct when the process (and its CPU) is always
 * alive. Production on Cloud Run with request-based billing sets
 * {@code APP_JOBS_IN_PROCESS=false} and lets Cloud Scheduler call
 * {@link InternalJobController} instead, so jobs are never run by both.
 */
@Component
@ConditionalOnProperty(name = "app.jobs.in-process", havingValue = "true", matchIfMissing = true)
public class InProcessJobScheduler {

    private final BackgroundJobRunner runner;

    public InProcessJobScheduler(BackgroundJobRunner runner) {
        this.runner = runner;
    }

    @Scheduled(fixedDelayString = "${app.booking.hold-expiry-check-ms:60000}")
    public void bookingHoldExpiry() {
        runner.run(BackgroundJob.BOOKING_HOLD_EXPIRY);
    }

    @Scheduled(fixedDelayString = "${app.booking.direct-payment-review-check-ms:60000}")
    public void directPaymentReview() {
        runner.run(BackgroundJob.DIRECT_PAYMENT_REVIEW);
    }

    @Scheduled(fixedDelayString = "${app.account-deletion.cleanup-interval-ms:300000}")
    public void accountDeletionCleanup() {
        runner.run(BackgroundJob.ACCOUNT_DELETION_CLEANUP);
    }

    @Scheduled(cron = "${app.booking.stay-transition-cron:0 5 * * * *}", zone = "Asia/Kolkata")
    public void stayTransitions() {
        runner.run(BackgroundJob.STAY_TRANSITIONS);
    }

    @Scheduled(cron = "${app.billing.reminder-cron:0 0 9 * * *}", zone = "Asia/Kolkata")
    public void feeReminders() {
        runner.run(BackgroundJob.FEE_REMINDERS);
    }

    @Scheduled(cron = "${app.notifications.engagement-cron:0 30 18 * * *}", zone = "Asia/Kolkata")
    public void engagementNotifications() {
        runner.run(BackgroundJob.ENGAGEMENT_NOTIFICATIONS);
    }
}
