package com.pgplatform.jobs;

import java.util.Arrays;
import java.util.Optional;

/**
 * Periodic maintenance work the backend must run on a timer. Each job can be
 * triggered either by the in-process Spring scheduler ({@link InProcessJobScheduler},
 * the default for local/dev) or externally by Cloud Scheduler through
 * {@link InternalJobController} when the service runs with request-based
 * billing and can scale to zero. See docs/decisions.md ADR on external job
 * triggering.
 *
 * <p>Every job must be safe to run twice or concurrently (retries, overlapping
 * triggers): each one re-checks state under its own transaction/locks.
 */
public enum BackgroundJob {
    BOOKING_HOLD_EXPIRY("booking-hold-expiry"),
    DIRECT_PAYMENT_REVIEW("direct-payment-review"),
    ACCOUNT_DELETION_CLEANUP("account-deletion-cleanup"),
    STAY_TRANSITIONS("stay-transitions"),
    FEE_REMINDERS("fee-reminders"),
    ENGAGEMENT_NOTIFICATIONS("engagement-notifications");

    private final String slug;

    BackgroundJob(String slug) {
        this.slug = slug;
    }

    public String slug() {
        return slug;
    }

    public static Optional<BackgroundJob> fromSlug(String slug) {
        return Arrays.stream(values()).filter(job -> job.slug.equals(slug)).findFirst();
    }
}
