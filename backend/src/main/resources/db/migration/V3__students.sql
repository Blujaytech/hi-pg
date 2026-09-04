-- V3: owner-managed student records (technical plan §6 Phase 4).
-- A student here is a data record only -- it is NOT a `users` login. Phase 11
-- (self-service booking) will decide how a real Student login connects to
-- one of these rows; don't assume today's shape survives that unchanged.

create table students (
    id                  uuid primary key,
    pg_id               uuid not null references pgs (id),
    bed_id              uuid references beds (id),
    full_name           varchar(255) not null,
    phone               varchar(20) not null,
    email               varchar(255),
    guardian_name       varchar(255),
    guardian_phone      varchar(20),
    permanent_address   text,
    id_proof_number     varchar(50),
    date_of_joining     date not null,
    status              varchar(20) not null default 'ACTIVE' check (status in ('ACTIVE', 'MOVED_OUT')),
    move_out_date       date,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),
    created_by          uuid,
    updated_by          uuid,
    deleted_at          timestamptz
);

create index idx_students_pg on students (pg_id) where deleted_at is null;
create index idx_students_bed on students (bed_id) where deleted_at is null;

-- Defense in depth alongside the service-layer check in StudentService: a bed
-- can only be the *active* assignment for one student at a time.
create unique index uq_students_active_bed on students (bed_id)
    where deleted_at is null and status = 'ACTIVE' and bed_id is not null;
