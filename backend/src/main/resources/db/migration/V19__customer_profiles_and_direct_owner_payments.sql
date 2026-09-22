-- Customer-controlled booking profile, explicit legal acceptances and the
-- owner-reviewed direct-UPI booking channel. Full Aadhaar numbers are never
-- accepted by this schema; identity_last_four is deliberately length-limited.

create table customer_profiles (
    id                    uuid primary key,
    user_id               uuid not null unique references users (id),
    full_name             varchar(255) not null,
    occupation            varchar(120),
    permanent_address     text,
    identity_type         varchar(24),
    identity_last_four    varchar(4),
    created_at            timestamptz not null default now(),
    updated_at            timestamptz not null default now(),
    created_by            uuid,
    updated_by            uuid,
    deleted_at            timestamptz,
    constraint chk_customer_profile_identity_type check (
        identity_type is null or identity_type in ('AADHAAR', 'PASSPORT', 'DRIVING_LICENCE', 'VOTER_ID', 'OTHER')
    ),
    constraint chk_customer_profile_identity_pair check (
        (identity_type is null and identity_last_four is null) or
        (identity_type is not null and identity_last_four ~ '^[A-Za-z0-9]{4}$')
    ),
    constraint chk_customer_profile_aadhaar_last_four check (
        identity_type <> 'AADHAAR' or identity_last_four ~ '^[0-9]{4}$'
    )
);

create table legal_acceptances (
    id                    uuid primary key,
    user_id               uuid not null references users (id),
    document_type         varchar(24) not null check (document_type in ('TERMS', 'PRIVACY', 'AADHAAR_CONSENT')),
    document_version      varchar(64) not null,
    accepted_at           timestamptz not null,
    ip_address            varchar(64),
    user_agent            varchar(500),
    locale                varchar(20),
    created_at            timestamptz not null default now(),
    updated_at            timestamptz not null default now(),
    created_by            uuid,
    updated_by            uuid,
    deleted_at            timestamptz
);

create unique index uq_legal_acceptance_version
    on legal_acceptances (user_id, document_type, document_version)
    where deleted_at is null;

create table pg_direct_payment_settings (
    id                    uuid primary key,
    pg_id                 uuid not null unique references pgs (id),
    enabled               boolean not null default false,
    beneficiary_name      varchar(255) not null,
    upi_id                varchar(320) not null,
    mobile_number         varchar(20) not null,
    verified              boolean not null default false,
    verified_at           timestamptz,
    created_at            timestamptz not null default now(),
    updated_at            timestamptz not null default now(),
    created_by            uuid,
    updated_by            uuid,
    deleted_at            timestamptz,
    constraint chk_direct_settings_verification check (
        (not enabled) or (verified and verified_at is not null)
    )
);

alter table bookings
    add column payment_channel varchar(20) not null default 'UNSELECTED';

alter table payment_orders add column paid_at timestamptz;
update payment_orders
set paid_at = updated_at
where status in ('PAID', 'REFUND_PENDING', 'REFUNDED') and paid_at is null;
create index idx_payment_orders_paid_booking
    on payment_orders (paid_at, booking_id)
    where purpose = 'BOOKING' and status = 'PAID' and deleted_at is null;

update bookings b
set payment_channel = 'RAZORPAY'
where exists (
    select 1 from payment_orders p
    where p.booking_id = b.id and p.status in ('PAID', 'REFUND_PENDING', 'REFUNDED') and p.deleted_at is null
);

alter table bookings
    add constraint chk_bookings_payment_channel
        check (payment_channel in ('UNSELECTED', 'RAZORPAY', 'DIRECT_UPI'));

alter table bookings drop constraint bookings_status_check;
alter table bookings alter column status type varchar(32);
alter table bookings add constraint bookings_status_check
    check (status in ('PAYMENT_PENDING', 'DIRECT_PAYMENT_REVIEW', 'CONFIRMED', 'CHECKED_IN',
                      'COMPLETED', 'CANCELLED', 'EXPIRED'));

alter table bookings drop constraint ex_bookings_no_active_overlap;
alter table bookings add constraint ex_bookings_no_active_overlap
    exclude using gist (
        bed_id with =,
        daterange(move_in_date, coalesce(check_out_date, 'infinity'::date), '[)') with &&
    )
    where (status in ('PAYMENT_PENDING', 'DIRECT_PAYMENT_REVIEW', 'CONFIRMED', 'CHECKED_IN')
           and deleted_at is null);

create table direct_payment_requests (
    id                          uuid primary key,
    booking_id                  uuid not null unique references bookings (id),
    pg_id                       uuid not null references pgs (id),
    customer_user_id            uuid not null references users (id),
    idempotency_key             varchar(100) not null unique,
    quoted_amount               numeric(10, 2) not null,
    currency                    varchar(3) not null default 'INR',
    transaction_reference       varchar(100) not null,
    status                      varchar(24) not null default 'PENDING',
    submitted_at                timestamptz not null,
    review_due_at               timestamptz not null,
    beneficiary_name_snapshot   varchar(255) not null,
    upi_id_snapshot             varchar(320) not null,
    mobile_number_snapshot      varchar(20) not null,
    confirmed_amount            numeric(10, 2),
    reviewed_by                 uuid references users (id),
    reviewed_at                 timestamptz,
    decision_idempotency_key    varchar(100) unique,
    review_note                 text,
    rejection_reason            text,
    created_at                  timestamptz not null default now(),
    updated_at                  timestamptz not null default now(),
    created_by                  uuid,
    updated_by                  uuid,
    deleted_at                  timestamptz,
    constraint chk_direct_payment_amount check (quoted_amount > 0 and (confirmed_amount is null or confirmed_amount > 0)),
    constraint chk_direct_payment_currency check (currency = 'INR'),
    constraint chk_direct_payment_status check (
        status in ('PENDING', 'APPROVED', 'REJECTED', 'REVIEW_OVERDUE', 'CANCELLED')
    ),
    constraint chk_direct_payment_decision check (
        (status = 'APPROVED' and confirmed_amount = quoted_amount and reviewed_by is not null
            and reviewed_at is not null and decision_idempotency_key is not null) or
        (status = 'REJECTED' and confirmed_amount is null and reviewed_by is not null
            and reviewed_at is not null and decision_idempotency_key is not null
            and rejection_reason is not null) or
        (status in ('PENDING', 'REVIEW_OVERDUE', 'CANCELLED') and confirmed_amount is null)
    )
);

create unique index uq_direct_payment_reference_per_pg
    on direct_payment_requests (pg_id, lower(transaction_reference))
    where deleted_at is null;
create index idx_direct_payment_owner_queue
    on direct_payment_requests (pg_id, status, submitted_at desc)
    where deleted_at is null;
create index idx_direct_payment_review_due
    on direct_payment_requests (review_due_at)
    where status = 'PENDING' and deleted_at is null;
