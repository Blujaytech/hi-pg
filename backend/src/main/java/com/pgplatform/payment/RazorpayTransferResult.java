package com.pgplatform.payment;

public record RazorpayTransferResult(String transferId, String status, boolean onHold) {
}
