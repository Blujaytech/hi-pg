-- Phase 12 added online Razorpay payments to the Java model and webhook flow,
-- but V4's original offline-only check constraint was never expanded.
alter table payments drop constraint payments_method_check;

alter table payments
    add constraint payments_method_check
    check (method in ('CASH', 'UPI', 'BANK_TRANSFER', 'CARD', 'OTHER', 'RAZORPAY'));

-- Receipts snapshot the payment method and therefore need the same enum set.
alter table receipts drop constraint receipts_method_check;

alter table receipts
    add constraint receipts_method_check
    check (method in ('CASH', 'UPI', 'BANK_TRANSFER', 'CARD', 'OTHER', 'RAZORPAY'));
