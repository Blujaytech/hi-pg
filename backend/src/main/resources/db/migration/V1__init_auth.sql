-- V1: users + auth support tables.
-- Soft-delete/audit convention (docs/decisions.md ADR-0002): every table below
-- carries created_at, updated_at, created_by, updated_by, deleted_at. Rows are
-- never hard-deleted by application code.

create table users (
    id              uuid primary key,
    email           varchar(255) unique,
    phone           varchar(20) unique,
    password_hash   varchar(255),
    full_name       varchar(255) not null,
    role            varchar(20) not null check (role in ('OWNER', 'STUDENT')),
    provider        varchar(20) not null default 'LOCAL' check (provider in ('LOCAL', 'GOOGLE')),
    status          varchar(20) not null default 'ACTIVE' check (status in ('ACTIVE', 'DISABLED')),
    email_verified  boolean not null default false,
    phone_verified  boolean not null default false,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    created_by      uuid,
    updated_by      uuid,
    deleted_at      timestamptz,
    constraint chk_users_identifier check (email is not null or phone is not null)
);

create index idx_users_role on users (role) where deleted_at is null;

create table refresh_tokens (
    id          uuid primary key,
    user_id     uuid not null references users (id),
    token_hash  varchar(255) not null unique,
    expires_at  timestamptz not null,
    revoked     boolean not null default false,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    created_by  uuid,
    updated_by  uuid,
    deleted_at  timestamptz
);

create index idx_refresh_tokens_user on refresh_tokens (user_id);

create table otp_codes (
    id          uuid primary key,
    phone       varchar(20) not null,
    code_hash   varchar(255) not null,
    purpose     varchar(40) not null,
    expires_at  timestamptz not null,
    attempts    int not null default 0,
    consumed    boolean not null default false,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    created_by  uuid,
    updated_by  uuid,
    deleted_at  timestamptz
);

create index idx_otp_codes_phone_purpose on otp_codes (phone, purpose, created_at desc);

create table password_reset_tokens (
    id          uuid primary key,
    user_id     uuid not null references users (id),
    token_hash  varchar(255) not null unique,
    expires_at  timestamptz not null,
    consumed    boolean not null default false,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    created_by  uuid,
    updated_by  uuid,
    deleted_at  timestamptz
);
