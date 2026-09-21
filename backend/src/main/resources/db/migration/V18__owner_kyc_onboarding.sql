create table owner_kyc_submissions (
    id                  uuid primary key,
    pg_id               uuid not null references pgs (id),
    legal_name          varchar(255) not null,
    pan_last_four       varchar(4) not null,
    aadhaar_last_four   varchar(4) not null,
    status              varchar(20) not null default 'DRAFT',
    review_note         text,
    submitted_at        timestamptz,
    reviewed_at         timestamptz,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),
    created_by          uuid,
    updated_by          uuid,
    deleted_at          timestamptz,
    constraint chk_owner_kyc_status check (status in ('DRAFT', 'SUBMITTED', 'VERIFIED', 'REJECTED'))
);

create unique index uq_owner_kyc_pg on owner_kyc_submissions (pg_id) where deleted_at is null;

create table owner_kyc_documents (
    id                  uuid primary key,
    submission_id       uuid not null references owner_kyc_submissions (id),
    document_type       varchar(32) not null,
    file_name           varchar(255) not null,
    content_type        varchar(100) not null,
    size_bytes          bigint not null,
    storage_key         varchar(500) not null,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),
    created_by          uuid,
    updated_by          uuid,
    deleted_at          timestamptz,
    constraint chk_owner_kyc_document_type check (
        document_type in ('PAN_CARD', 'AADHAAR_FRONT', 'AADHAAR_BACK', 'OWNER_PHOTO', 'PG_PHOTO', 'ADDRESS_PROOF')
    )
);

create unique index uq_owner_kyc_document_type
    on owner_kyc_documents (submission_id, document_type) where deleted_at is null;
