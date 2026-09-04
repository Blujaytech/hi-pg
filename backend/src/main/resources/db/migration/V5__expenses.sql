-- V5: expense tracking (technical plan §6 Phase 5b). Low coupling to fees/payments -- its own table, no FK to them.

create table expenses (
    id              uuid primary key,
    pg_id           uuid not null references pgs (id),
    category        varchar(20) not null check (category in ('MAINTENANCE', 'UTILITIES', 'SALARY', 'SUPPLIES', 'OTHER')),
    description     varchar(500) not null,
    amount          numeric(10, 2) not null check (amount > 0),
    expense_date    date not null,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    created_by      uuid,
    updated_by      uuid,
    deleted_at      timestamptz
);

create index idx_expenses_pg on expenses (pg_id) where deleted_at is null;
create index idx_expenses_pg_date on expenses (pg_id, expense_date) where deleted_at is null;
