alter table pgs add column location_url varchar(1000);
alter table pgs drop constraint if exists pgs_gender_preference_check;
alter table pgs add constraint pgs_gender_preference_check
    check (gender_preference in ('MALE', 'FEMALE', 'CO_ED', 'UNSPECIFIED'));

create table pg_import_batches (
    id uuid primary key,
    file_name varchar(255) not null,
    file_sha256 varchar(64) not null unique,
    source_sheet varchar(255) not null,
    status varchar(24) not null,
    total_rows integer not null default 0,
    publishable_rows integer not null default 0,
    warning_rows integer not null default 0,
    invalid_rows integer not null default 0,
    duplicate_rows integer not null default 0,
    valid_mobile_rows integer not null default 0,
    published_rows integer not null default 0,
    invited_rows integer not null default 0,
    skipped_rows integer not null default 0,
    completed_at timestamptz,
    created_at timestamptz not null,
    updated_at timestamptz not null,
    created_by uuid,
    updated_by uuid,
    deleted_at timestamptz
);
create index idx_pg_import_batches_active on pg_import_batches(created_at desc) where deleted_at is null;

create table pg_import_rows (
    id uuid primary key,
    batch_id uuid not null references pg_import_batches(id),
    source_row_number integer not null,
    name varchar(255),
    owner_name varchar(120),
    owner_mobile varchar(20),
    address varchar(500),
    city varchar(120),
    state varchar(120),
    pincode varchar(12),
    latitude double precision,
    longitude double precision,
    location_url varchar(1000),
    proper_locality varchar(255),
    original_stay_type varchar(120),
    gender_preference varchar(20),
    validation_status varchar(24) not null,
    validation_messages text,
    dedupe_key varchar(1000),
    publish_status varchar(24) not null,
    invitation_status varchar(24) not null,
    published_pg_id uuid references pgs(id),
    created_at timestamptz not null,
    updated_at timestamptz not null,
    created_by uuid,
    updated_by uuid,
    deleted_at timestamptz
);
create index idx_pg_import_rows_batch on pg_import_rows(batch_id, source_row_number) where deleted_at is null;
create index idx_pg_import_rows_dedupe on pg_import_rows(dedupe_key) where deleted_at is null;
