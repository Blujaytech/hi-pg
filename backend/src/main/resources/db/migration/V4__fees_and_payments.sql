-- V4: fee management (technical plan §6 Phase 5). Offline payment recording
-- only -- Razorpay/online payments are Phase 12 and will likely add columns
-- (gateway order id, idempotency key) to `payments` rather than a new table.

create table fees (
    id              uuid primary key,
    student_id      uuid not null references students (id),
    pg_id           uuid not null references pgs (id),
    period_month    int not null check (period_month between 1 and 12),
    period_year     int not null check (period_year >= 2000),
    amount          numeric(10, 2) not null check (amount > 0),
    due_date        date not null,
    status          varchar(20) not null default 'PENDING' check (status in ('PENDING', 'PARTIALLY_PAID', 'PAID')),
    notes           text,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    created_by      uuid,
    updated_by      uuid,
    deleted_at      timestamptz
);

create index idx_fees_student on fees (student_id) where deleted_at is null;
create index idx_fees_pg on fees (pg_id) where deleted_at is null;
-- One fee per student per billing period.
create unique index uq_fees_student_period on fees (student_id, period_year, period_month) where deleted_at is null;

create table payments (
    id              uuid primary key,
    fee_id          uuid not null references fees (id),
    amount_paid     numeric(10, 2) not null check (amount_paid > 0),
    paid_on         date not null,
    method          varchar(20) not null check (method in ('CASH', 'UPI', 'BANK_TRANSFER', 'CARD', 'OTHER')),
    reference       varchar(120),
    note            text,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    created_by      uuid,
    updated_by      uuid,
    deleted_at      timestamptz
);

create index idx_payments_fee on payments (fee_id) where deleted_at is null;
