package com.pgplatform.owner;

public record OwnerSmsResult(OwnerSmsStatus status, String providerMessageId, String failureReason) {
    public boolean sent() { return status == OwnerSmsStatus.SENT; }
}
