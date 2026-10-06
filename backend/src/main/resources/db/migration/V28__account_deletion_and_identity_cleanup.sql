-- Production account-deletion support. The user row remains as an anonymous
-- referential anchor for legally retained booking/payment records, while all
-- login identifiers and profile data are removed by AccountDeletionService.

alter table users add column firebase_subject varchar(128);

create unique index uq_users_firebase_subject
    on users (firebase_subject)
    where firebase_subject is not null;

create table account_deletion_audits (
    id                          uuid primary key,
    account_id                  uuid not null,
    role                        varchar(20) not null,
    retention_policy_version    varchar(64) not null,
    retained_data_summary       varchar(500) not null,
    requested_at                timestamptz not null,
    completed_at                timestamptz not null,
    created_at                  timestamptz not null default now()
);

create index idx_account_deletion_audits_account
    on account_deletion_audits (account_id, requested_at desc);

-- Object storage is external to the database. Keys are kept only while a
-- private-object deletion is pending; successful cleanup clears the key.
create table account_deletion_storage_cleanup (
    id                  uuid primary key,
    audit_id            uuid not null references account_deletion_audits (id),
    storage_key         varchar(500),
    status              varchar(20) not null default 'PENDING'
                            check (status in ('PENDING', 'COMPLETED')),
    attempt_count       integer not null default 0,
    last_error          varchar(500),
    next_attempt_at     timestamptz not null default now(),
    completed_at        timestamptz,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now()
);

create index idx_account_deletion_cleanup_pending
    on account_deletion_storage_cleanup (next_attempt_at)
    where status = 'PENDING';
