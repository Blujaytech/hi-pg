package com.pgplatform.deposit.dto;

import com.pgplatform.deposit.DepositTransaction;
import com.pgplatform.deposit.DepositTransactionStatus;
import com.pgplatform.deposit.DepositTransactionType;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public record DepositLedgerResponse(UUID bookingId, BigDecimal collected, BigDecimal deducted,
                                    BigDecimal refunded, BigDecimal availableBalance,
                                    List<Entry> entries) {
    public record Entry(UUID id, DepositTransactionType type, BigDecimal amount, String reason,
                        DepositTransactionStatus status, String razorpayRefundId, Instant createdAt) {
        public static Entry from(DepositTransaction transaction) {
            return new Entry(transaction.getId(), transaction.getType(), transaction.getAmount(),
                    transaction.getReason(), transaction.getStatus(), transaction.getRazorpayRefundId(),
                    transaction.getCreatedAt());
        }
    }
}
