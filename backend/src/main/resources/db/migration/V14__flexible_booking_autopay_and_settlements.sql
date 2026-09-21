-- Flexible room/bed inventory, date-range bookings, Razorpay marketplace
-- bookkeeping, fee extensions/reminders, AutoPay mandates, and deposit ledger.

create extension if not exists btree_gist;

-- Admin is deliberately not self-sign-up capable. Production administrators
-- are provisioned out-of-band and use the same authenticated API boundary.
alter table users drop constraint users_role_check;
alter table users add constraint users_role_check check (role in ('OWNER', 'STUDENT', 'ADMIN'));

alter table pgs
    add column payment_onboarding_status varchar(24) not null default 'NOT_STARTED',
    add column razorpay_linked_account_id varchar(100),
    add column platform_commission_bps integer not null default 0,
    add constraint chk_pgs_payment_onboarding_status
        check (payment_onboarding_status in ('NOT_STARTED', 'PENDING', 'VERIFIED', 'REJECTED')),
    add constraint chk_pgs_platform_commission_bps
        check (platform_commission_bps between 0 and 10000);

create unique index uq_pgs_razorpay_linked_account
    on pgs (razorpay_linked_account_id)
    where razorpay_linked_account_id is not null and deleted_at is null;

alter table rooms
    add column booking_mode varchar(20) not null default 'MONTHLY',
    add column day_wise_rate numeric(10, 2),
    add column notice_period_days integer not null default 15,
    add column security_deposit numeric(10, 2) not null default 0,
    add constraint chk_rooms_booking_mode check (booking_mode in ('MONTHLY', 'DAY_WISE', 'MIXED')),
    add constraint chk_rooms_day_wise_rate check (day_wise_rate is null or day_wise_rate >= 0),
    add constraint chk_rooms_notice_period check (notice_period_days between 0 and 90),
    add constraint chk_rooms_security_deposit check (security_deposit >= 0);

alter table beds
    add column booking_mode varchar(20) not null default 'MONTHLY',
    add constraint chk_beds_booking_mode check (booking_mode in ('MONTHLY', 'DAY_WISE', 'FLEXIBLE'));

-- Existing bookings were monthly, open-ended stays. Preserve them as such.
drop index uq_bookings_bed_confirmed;
alter table bookings drop constraint bookings_status_check;
alter table bookings alter column confirmed_at drop not null;
alter table bookings
    add column booking_type varchar(20) not null default 'MONTHLY',
    add column check_out_date date,
    add column rent_amount numeric(10, 2) not null default 0,
    add column security_deposit_amount numeric(10, 2) not null default 0,
    add column total_amount numeric(10, 2) not null default 0,
    add column payment_expires_at timestamptz,
    add column checked_in_at timestamptz,
    add column completed_at timestamptz,
    add column notice_given_at timestamptz,
    add column planned_move_out_date date,
    add column notice_shortfall_days integer not null default 0,
    add constraint bookings_status_check
        check (status in ('PAYMENT_PENDING', 'CONFIRMED', 'CHECKED_IN', 'COMPLETED', 'CANCELLED', 'EXPIRED')),
    add constraint chk_bookings_type check (booking_type in ('MONTHLY', 'DAY_WISE')),
    add constraint chk_bookings_checkout check (check_out_date is null or check_out_date > move_in_date),
    add constraint chk_bookings_day_wise_checkout check (booking_type <> 'DAY_WISE' or check_out_date is not null),
    add constraint chk_bookings_amounts check (
        rent_amount >= 0 and security_deposit_amount >= 0 and total_amount >= 0
    ),
    add constraint chk_bookings_notice_shortfall check (notice_shortfall_days >= 0);

-- The calendar invariant: active intervals for one physical bed never overlap.
-- [) permits a new guest to check in on the date the prior guest checks out.
alter table bookings add constraint ex_bookings_no_active_overlap
    exclude using gist (
        bed_id with =,
        daterange(move_in_date, coalesce(check_out_date, 'infinity'::date), '[)') with &&
    )
    where (status in ('PAYMENT_PENDING', 'CONFIRMED', 'CHECKED_IN') and deleted_at is null);

create index idx_bookings_bed_dates on bookings (bed_id, move_in_date, check_out_date)
    where deleted_at is null;
create index idx_bookings_expiring_holds on bookings (payment_expires_at)
    where status = 'PAYMENT_PENDING' and deleted_at is null;

-- A payment order now targets either a fee or a booking. Existing rows remain
-- fee orders. The check prevents orphan and ambiguous financial records.
alter table payment_orders alter column fee_id drop not null;
alter table payment_orders
    add column booking_id uuid references bookings (id),
    add column purpose varchar(24) not null default 'FEE',
    add column razorpay_transfer_id varchar(100),
    add column transfer_status varchar(24) not null default 'NOT_CREATED',
    add column owner_amount numeric(10, 2),
    add constraint chk_payment_orders_purpose check (purpose in ('BOOKING', 'FEE', 'AUTOPAY')),
    add constraint chk_payment_orders_target check (
        (fee_id is not null and booking_id is null) or
        (fee_id is null and booking_id is not null)
    ),
    add constraint chk_payment_orders_transfer_status check (
        transfer_status in ('NOT_CREATED', 'ON_HOLD', 'PENDING', 'PROCESSED', 'FAILED', 'REVERSED')
    );

create index idx_payment_orders_booking on payment_orders (booking_id) where deleted_at is null;
create unique index uq_payment_orders_transfer on payment_orders (razorpay_transfer_id)
    where razorpay_transfer_id is not null and deleted_at is null;

-- Owner-approved due date changes. Current effective values are copied onto
-- fees for fast reads; this table is the immutable audit history.
alter table fees
    add column extended_due_date date,
    add column extension_count integer not null default 0,
    add column extension_note text,
    add constraint chk_fees_extension_count check (extension_count >= 0),
    add constraint chk_fees_extended_due_date check (
        extended_due_date is null or extended_due_date > due_date
    );

create table fee_extensions (
    id                  uuid primary key,
    fee_id              uuid not null references fees (id),
    owner_id            uuid not null references users (id),
    previous_due_date   date not null,
    new_due_date        date not null,
    note                text,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),
    created_by          uuid,
    updated_by          uuid,
    deleted_at          timestamptz,
    constraint chk_fee_extension_dates check (new_due_date > previous_due_date)
);

create index idx_fee_extensions_fee on fee_extensions (fee_id, created_at desc)
    where deleted_at is null;

-- Makes scheduled notifications safe across retries/restarts.
create table fee_notification_deliveries (
    id              uuid primary key,
    fee_id          uuid not null references fees (id),
    notification_type varchar(32) not null,
    effective_due_date date not null,
    delivered_at    timestamptz not null,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    created_by      uuid,
    updated_by      uuid,
    deleted_at      timestamptz,
    constraint chk_fee_notification_type check (
        notification_type in ('DUE_TODAY', 'OVERDUE_DAY_3', 'EXTENSION_DUE', 'EXTENSION_OVERDUE')
    )
);

create unique index uq_fee_notification_delivery
    on fee_notification_deliveries (fee_id, notification_type, effective_due_date)
    where deleted_at is null;

create table autopay_mandates (
    id                          uuid primary key,
    student_id                  uuid not null references students (id),
    pg_id                       uuid not null references pgs (id),
    amount                      numeric(10, 2) not null check (amount > 0),
    due_day                     integer not null check (due_day between 1 and 28),
    status                      varchar(32) not null,
    razorpay_plan_id            varchar(100),
    razorpay_subscription_id    varchar(100),
    next_charge_date            date,
    failure_reason              text,
    created_at                  timestamptz not null default now(),
    updated_at                  timestamptz not null default now(),
    created_by                  uuid,
    updated_by                  uuid,
    deleted_at                  timestamptz,
    constraint chk_autopay_status check (
        status in ('PENDING_AUTHORIZATION', 'ACTIVE', 'PAUSED', 'FAILED', 'HALTED', 'CANCELLED')
    )
);

create unique index uq_autopay_active_student
    on autopay_mandates (student_id)
    where status in ('PENDING_AUTHORIZATION', 'ACTIVE', 'PAUSED', 'FAILED') and deleted_at is null;
create unique index uq_autopay_subscription
    on autopay_mandates (razorpay_subscription_id)
    where razorpay_subscription_id is not null and deleted_at is null;

create table deposit_transactions (
    id                  uuid primary key,
    booking_id          uuid not null references bookings (id),
    type                varchar(24) not null,
    amount              numeric(10, 2) not null check (amount > 0),
    reason              text,
    razorpay_refund_id  varchar(100),
    status              varchar(20) not null default 'COMPLETED',
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),
    created_by          uuid,
    updated_by          uuid,
    deleted_at          timestamptz,
    constraint chk_deposit_type check (type in ('COLLECTED', 'DEDUCTION', 'REFUND')),
    constraint chk_deposit_status check (status in ('PENDING', 'COMPLETED', 'FAILED'))
);

create index idx_deposit_transactions_booking on deposit_transactions (booking_id, created_at)
    where deleted_at is null;
create unique index uq_deposit_refund on deposit_transactions (razorpay_refund_id)
    where razorpay_refund_id is not null and deleted_at is null;
