package com.pgplatform.autopay;

public enum AutoPayStatus {
    PENDING_AUTHORIZATION,
    ACTIVE,
    PAUSED,
    FAILED,
    HALTED,
    CANCELLED
}
