-- Admin-curated public listings, OTP-based owner claims, verification gating,
-- and customer demand signals. Owner contact data never appears in a public DTO.
alter table pgs alter column owner_id drop not null;

alter table pgs add column admin_created boolean not null default false;
alter table pgs add column claim_status varchar(24) not null default 'CLAIMED';
alter table pgs add column verification_status varchar(24) not null default 'UNVERIFIED';
alter table pgs add column booking_enabled boolean not null default false;

update pgs p
set claim_status = case when p.owner_id is null then 'UNCLAIMED' else 'CLAIMED' end,
    verification_status = case when exists (
        select 1 from owner_kyc_submissions k
        where k.pg_id = p.id and k.deleted_at is null and k.status = 'VERIFIED'
    ) then 'VERIFIED' else 'UNVERIFIED' end,
    booking_enabled = exists (
        select 1 from owner_kyc_submissions k
        where k.pg_id = p.id and k.deleted_at is null and k.status = 'VERIFIED'
    );

alter table pgs add constraint chk_pg_claim_status
    check (claim_status in ('UNCLAIMED', 'CLAIM_PENDING', 'CLAIMED'));
alter table pgs add constraint chk_pg_verification_status
    check (verification_status in ('UNVERIFIED', 'PENDING', 'VERIFIED', 'REJECTED'));

create table pg_owner_contacts (
    id                  uuid primary key,
    pg_id               uuid not null references pgs (id),
    owner_name          varchar(120),
    normalized_mobile   varchar(20) not null,
    invitation_status   varchar(24) not null default 'NOT_SENT'
                            check (invitation_status in ('NOT_SENT', 'PENDING_PROVIDER', 'SENT', 'CLAIMED')),
    invited_at          timestamptz,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),
    created_by          uuid,
    updated_by          uuid,
    deleted_at          timestamptz
);
create unique index uq_pg_owner_contact_pg on pg_owner_contacts (pg_id) where deleted_at is null;
create index idx_pg_owner_contact_mobile on pg_owner_contacts (normalized_mobile) where deleted_at is null;

create table pg_claim_requests (
    id                  uuid primary key,
    pg_id               uuid not null references pgs (id),
    claimant_user_id    uuid not null references users (id),
    matched_mobile      varchar(20) not null,
    status              varchar(20) not null default 'PENDING'
                            check (status in ('PENDING', 'APPROVED', 'REJECTED')),
    review_note         text,
    submitted_at        timestamptz not null default now(),
    reviewed_at         timestamptz,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),
    created_by          uuid,
    updated_by          uuid,
    deleted_at          timestamptz
);
create unique index uq_pg_claim_open on pg_claim_requests (pg_id) where deleted_at is null and status = 'PENDING';
create index idx_pg_claim_claimant on pg_claim_requests (claimant_user_id, created_at desc) where deleted_at is null;

create table pg_interest_requests (
    id                  uuid primary key,
    pg_id               uuid not null references pgs (id),
    customer_user_id    uuid not null references users (id),
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),
    created_by          uuid,
    updated_by          uuid,
    deleted_at          timestamptz
);
create unique index uq_pg_interest_customer on pg_interest_requests (pg_id, customer_user_id)
    where deleted_at is null;
create index idx_pg_interest_pg on pg_interest_requests (pg_id, created_at desc) where deleted_at is null;
