-- One booking can have at most one open/captured checkout. Failed attempts
-- remain auditable and may be retried with a new order.
create unique index uq_payment_orders_active_booking
    on payment_orders (booking_id)
    where booking_id is not null
      and status in ('CREATED', 'PAID')
      and deleted_at is null;
