alter table payment_orders drop constraint payment_orders_status_check;
alter table payment_orders add constraint payment_orders_status_check
    check (status in ('CREATED', 'PAID', 'FAILED', 'REFUND_PENDING', 'REFUNDED'));
alter table payment_orders add column razorpay_refund_id varchar(100);
create unique index uq_payment_orders_refund
    on payment_orders (razorpay_refund_id)
    where razorpay_refund_id is not null and deleted_at is null;
