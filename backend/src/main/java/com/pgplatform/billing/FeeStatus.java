package com.pgplatform.billing;

/** Stored status only tracks payment progress. "Overdue" is a derived, computed flag (dueDate passed + not PAID) -- see FeeResponse -- not a stored state, so nothing has to flip it on a schedule. */
public enum FeeStatus {
    PENDING,
    PARTIALLY_PAID,
    PAID
}
