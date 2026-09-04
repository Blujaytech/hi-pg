-- V7: receipts, auto-generated from payments (technical plan §6 Phase 7b).
-- Depends on V4 (fees/payments) being in place.

create sequence receipt_number_seq start with 1 increment by 1;

create table receipts (
    id                      uuid primary key,
    receipt_number          varchar(32) not null unique,
    payment_id              uuid not null unique references payments (id),
    student_id              uuid not null references students (id),
    pg_id                   uuid not null references pgs (id),
    student_name_snapshot   varchar(255) not null,
    pg_name_snapshot        varchar(255) not null,
    fee_period_month        int not null,
    fee_period_year         int not null,
    amount                  numeric(10, 2) not null check (amount > 0),
    paid_on                 date not null,
    method                  varchar(20) not null check (method in ('CASH', 'UPI', 'BANK_TRANSFER', 'CARD', 'OTHER')),
    created_at              timestamptz not null default now(),
    updated_at              timestamptz not null default now(),
    created_by              uuid,
    updated_by              uuid,
    deleted_at              timestamptz
);

create index idx_receipts_student on receipts (student_id) where deleted_at is null;
create index idx_receipts_pg on receipts (pg_id) where deleted_at is null;
