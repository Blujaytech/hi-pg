-- V6: complaint management (technical plan §6 Phase 6). Owner-side only for
-- now -- see docs/decisions.md for why student self-service filing waits.

create table complaints (
    id                  uuid primary key,
    student_id          uuid not null references students (id),
    pg_id               uuid not null references pgs (id),
    category            varchar(20) not null check (category in ('MAINTENANCE', 'CLEANLINESS', 'NOISE', 'SECURITY', 'BILLING', 'OTHER')),
    priority            varchar(10) not null default 'MEDIUM' check (priority in ('LOW', 'MEDIUM', 'HIGH')),
    description         text not null,
    status              varchar(20) not null default 'OPEN' check (status in ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED')),
    resolution_notes    text,
    resolved_at         timestamptz,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),
    created_by          uuid,
    updated_by          uuid,
    deleted_at          timestamptz
);

create index idx_complaints_student on complaints (student_id) where deleted_at is null;
create index idx_complaints_pg on complaints (pg_id) where deleted_at is null;
create index idx_complaints_pg_status on complaints (pg_id, status) where deleted_at is null;
