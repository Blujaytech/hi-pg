-- V10: Razorpay payment orders (technical plan §6 Phase 12 / §7 item 4:
-- "idempotent payments needs a concrete mechanism"). idempotency_key is
-- client-generated (one per payment attempt) and unique at the DB level --
-- retrying the same attempt (e.g. after a dropped response) returns the
-- same order instead of creating a duplicate. Actually calling out to
-- Razorpay is still stubbed (no API credentials provisioned) -- see
-- RazorpayGateway / StubRazorpayGateway and docs/decisions.md -- so in
-- practice no row can be created successfully yet, same situation as
-- documents (V8) and Google OAuth.

create table payment_orders (
    id                  uuid primary key,
    fee_id              uuid not null references fees (id),
    idempotency_key     varchar(100) not null,
    amount              numeric(10, 2) not null check (amount > 0),
    currency            varchar(3) not null default 'INR',
    status              varchar(20) not null check (status in ('CREATED', 'PAID', 'FAILED')),
    razorpay_order_id   varchar(100) unique,
    razorpay_payment_id varchar(100) unique,
    failure_reason      text,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),
    created_by          uuid,
    updated_by          uuid,
    deleted_at          timestamptz
);

create unique index uq_payment_orders_idempotency_key on payment_orders (idempotency_key);
create index idx_payment_orders_fee on payment_orders (fee_id) where deleted_at is null;
