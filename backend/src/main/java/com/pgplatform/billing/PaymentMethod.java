package com.pgplatform.billing;

/** RAZORPAY (online, Phase 12) joins the offline-recording methods from Phase 5. */
public enum PaymentMethod {
    CASH,
    UPI,
    BANK_TRANSFER,
    CARD,
    RAZORPAY,
    OTHER
}
