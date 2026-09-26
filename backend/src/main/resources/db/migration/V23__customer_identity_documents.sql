-- Replace partial government-ID number collection with a private document.
-- The object bytes live in R2; Postgres stores only metadata and the private key.

update customer_profiles
set identity_type = null,
    identity_last_four = null
where identity_type not in ('AADHAAR', 'PASSPORT');

update customer_profiles
set identity_last_four = null
where identity_last_four is not null;

alter table customer_profiles
    drop constraint if exists chk_customer_profile_identity_pair,
    drop constraint if exists chk_customer_profile_aadhaar_last_four,
    drop constraint if exists chk_customer_profile_identity_type;

alter table customer_profiles
    add constraint chk_customer_profile_identity_type
        check (identity_type is null or identity_type in ('AADHAAR', 'PASSPORT')),
    add constraint chk_customer_profile_identity_number_not_collected
        check (identity_last_four is null);

create table customer_identity_documents (
    id              uuid primary key,
    profile_id      uuid not null references customer_profiles (id),
    identity_type   varchar(24) not null check (identity_type in ('AADHAAR', 'PASSPORT')),
    file_name       varchar(255) not null,
    content_type    varchar(120) not null,
    size_bytes      bigint not null check (size_bytes > 0 and size_bytes <= 10485760),
    storage_key     varchar(500) not null,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    created_by      uuid,
    updated_by      uuid,
    deleted_at      timestamptz
);

create unique index uq_customer_identity_document_profile
    on customer_identity_documents (profile_id)
    where deleted_at is null;
