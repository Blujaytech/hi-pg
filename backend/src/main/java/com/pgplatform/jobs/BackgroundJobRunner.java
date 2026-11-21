package com.pgplatform.jobs;

import com.pgplatform.auth.AccountDeletionStorageCleanupService;
import com.pgplatform.billing.FeeReminderService;
import com.pgplatform.booking.BookingService;
import com.pgplatform.notification.EngagementNotificationService;
import com.pgplatform.payment.DirectPaymentService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Component;

/**
 * Single place that knows how to execute each {@link BackgroundJob}. Calls go
 * through the services' Spring proxies so their {@code @Transactional}
 * boundaries still apply.
 */
@Component
public class BackgroundJobRunner {

    private static final Logger log = LoggerFactory.getLogger(BackgroundJobRunner.class);

    public enum Outcome { COMPLETED, SKIPPED }

    private final BookingService bookingService;
    private final DirectPaymentService directPaymentService;
    private final AccountDeletionStorageCleanupService accountDeletionCleanup;
    private final FeeReminderService feeReminderService;
    private final ObjectProvider<EngagementNotificationService> engagementNotifications;

    public BackgroundJobRunner(BookingService bookingService,
                               DirectPaymentService directPaymentService,
                               AccountDeletionStorageCleanupService accountDeletionCleanup,
                               FeeReminderService feeReminderService,
                               ObjectProvider<EngagementNotificationService> engagementNotifications) {
        this.bookingService = bookingService;
        this.directPaymentService = directPaymentService;
        this.accountDeletionCleanup = accountDeletionCleanup;
        this.feeReminderService = feeReminderService;
        this.engagementNotifications = engagementNotifications;
    }

    public Outcome run(BackgroundJob job) {
        long started = System.nanoTime();
        Outcome outcome = switch (job) {
            case BOOKING_HOLD_EXPIRY -> completed(bookingService::expirePaymentHolds);
            case DIRECT_PAYMENT_REVIEW -> completed(directPaymentService::markOverdueReviews);
            case ACCOUNT_DELETION_CLEANUP -> completed(accountDeletionCleanup::retryPending);
            case STAY_TRANSITIONS -> completed(bookingService::transitionDueStays);
            case FEE_REMINDERS -> completed(feeReminderService::sendScheduledReminders);
            case ENGAGEMENT_NOTIFICATIONS -> {
                // Feature-flagged bean (app.notifications.engagement-enabled); absent means disabled.
                EngagementNotificationService service = engagementNotifications.getIfAvailable();
                if (service == null) {
                    yield Outcome.SKIPPED;
                }
                yield completed(service::sendScheduledEngagements);
            }
        };
        log.debug("Background job {} {} in {} ms", job.slug(), outcome,
                (System.nanoTime() - started) / 1_000_000);
        return outcome;
    }

    private static Outcome completed(Runnable work) {
        work.run();
        return Outcome.COMPLETED;
    }
}
