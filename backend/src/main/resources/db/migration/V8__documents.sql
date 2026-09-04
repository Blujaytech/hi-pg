-- V8: document metadata (technical plan §6 Phase 7a / §7 item 1). Storage
-- itself is not wired up yet -- see DocumentStorageGateway /
-- StubDocumentStorageGateway and docs/decisions.md. This table exists now so
-- the API contract and Flutter/web screens can be built against it; rows in
-- practice cannot be created successfully until real object storage exists.

create table documents (
    id              uuid primary key,
    student_id      uuid not null references students (id),
    pg_id           uuid not null references pgs (id),
    document_type   varchar(20) not null check (document_type in ('ID_PROOF', 'PHOTO', 'OTHER')),
    file_name       varchar(255) not null,
    content_type    varchar(120) not null,
    size_bytes      bigint not null check (size_bytes >= 0),
    storage_key     varchar(500),
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    created_by      uuid,
    updated_by      uuid,
    deleted_at      timestamptz
);

create index idx_documents_student on documents (student_id) where deleted_at is null;
