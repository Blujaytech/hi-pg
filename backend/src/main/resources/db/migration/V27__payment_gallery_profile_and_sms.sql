alter table direct_payment_requests add column payment_method varchar(16) not null default 'UPI';
alter table direct_payment_requests alter column transaction_reference drop not null;
alter table direct_payment_requests add constraint ck_direct_payment_method
    check (payment_method in ('UPI', 'CASH'));
alter table direct_payment_requests add constraint ck_direct_payment_reference_by_method
    check ((payment_method = 'UPI' and transaction_reference is not null)
        or (payment_method = 'CASH' and transaction_reference is null));

drop index if exists uq_direct_payment_reference_per_pg;
create unique index uq_direct_payment_reference_per_pg
    on direct_payment_requests (pg_id, lower(transaction_reference))
    where deleted_at is null and transaction_reference is not null;

create table pg_photos (
    id uuid primary key,
    pg_id uuid not null references pgs(id),
    storage_key varchar(500) not null unique,
    original_file_name varchar(255) not null,
    content_type varchar(100) not null,
    file_size bigint not null,
    display_order integer not null default 0,
    is_cover boolean not null default false,
    created_at timestamptz not null,
    updated_at timestamptz not null,
    created_by uuid,
    updated_by uuid,
    deleted_at timestamptz
);
create index idx_pg_photos_active on pg_photos(pg_id, display_order) where deleted_at is null;

alter table customer_profiles add column profile_photo_storage_key varchar(500);
alter table customer_profiles add column profile_photo_file_name varchar(255);
alter table customer_profiles add column profile_photo_content_type varchar(100);

create table owner_sms_messages (
    id uuid primary key,
    pg_id uuid not null references pgs(id),
    event_key varchar(100) not null,
    recipient_mobile varchar(20) not null,
    message_text text not null,
    provider varchar(32) not null,
    status varchar(24) not null,
    provider_message_id varchar(255),
    failure_reason text,
    created_at timestamptz not null,
    updated_at timestamptz not null,
    created_by uuid,
    updated_by uuid,
    deleted_at timestamptz,
    constraint uq_owner_sms_pg_event unique(pg_id, event_key)
);
