package com.pgplatform.payment;

/** What a real Razorpay "create order" API call would hand back. */
public record RazorpayOrderResult(String razorpayOrderId) {
}
