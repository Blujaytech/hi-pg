-- V9: links a Student LOGIN (users row, role=STUDENT) to a Student RECORD,
-- and adds Bookings (technical plan §6 Phase 11). Before this migration a
-- Student record was purely owner-managed data with no login attached
-- (see Student.java's javadoc from Phase 4) -- self-service booking is what
-- finally needs that link, so it's created here rather than earlier.

alter table students add column user_id uuid unique references users (id);

create table bookings (
    id                    uuid primary key,
    student_id            uuid not null references students (id),
    bed_id                uuid not null references beds (id),
    pg_id                 uuid not null references pgs (id),
    status                varchar(20) not null check (status in ('CONFIRMED', 'CANCELLED')),
    move_in_date          date not null,
    confirmed_at          timestamptz not null,
    cancelled_at          timestamptz,
    cancellation_reason   text,
    created_at            timestamptz not null default now(),
    updated_at            timestamptz not null default now(),
    created_by            uuid,
    updated_by            uuid,
    deleted_at            timestamptz
);

-- The hard guarantee this whole phase exists for: at most one CONFIRMED,
-- non-deleted booking per bed at any time. BookingService.book() already
-- enforces this with a pessimistic row lock (SELECT ... FOR UPDATE on the
-- bed) before ever inserting a booking -- this index is defense-in-depth,
-- not the primary mechanism, matching the project's existing pattern (see
-- uq_fees_student_period, uq_students_active_bed).
create unique index uq_bookings_bed_confirmed on bookings (bed_id) where status = 'CONFIRMED' and deleted_at is null;

create index idx_bookings_student on bookings (student_id) where deleted_at is null;
