alter table pg_import_rows add column image_count integer not null default 0;

create table pg_import_photos (
    id uuid primary key,
    import_row_id uuid not null references pg_import_rows(id),
    original_file_name varchar(255) not null,
    content_type varchar(100) not null,
    file_size bigint not null,
    display_order integer not null,
    content bytea,
    storage_key varchar(500),
    created_at timestamptz not null,
    updated_at timestamptz not null,
    created_by uuid,
    updated_by uuid,
    deleted_at timestamptz
);

create index idx_pg_import_photos_active
    on pg_import_photos(import_row_id, display_order)
    where deleted_at is null;

create unique index uq_pg_import_photos_storage_key
    on pg_import_photos(storage_key)
    where storage_key is not null;
