-- V2: Owner hierarchy -- PG -> Floor -> Room -> Bed (technical plan §6 Phase 2).

create table pgs (
    id                  uuid primary key,
    owner_id            uuid not null references users (id),
    name                varchar(255) not null,
    address             varchar(500) not null,
    city                varchar(120) not null,
    state               varchar(120),
    pincode             varchar(12),
    latitude            double precision,
    longitude           double precision,
    description         text,
    gender_preference   varchar(20) not null default 'CO_ED' check (gender_preference in ('MALE', 'FEMALE', 'CO_ED')),
    status              varchar(20) not null default 'ACTIVE' check (status in ('ACTIVE', 'INACTIVE')),
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),
    created_by          uuid,
    updated_by          uuid,
    deleted_at          timestamptz
);

create index idx_pgs_owner on pgs (owner_id) where deleted_at is null;
create index idx_pgs_city on pgs (city) where deleted_at is null;

create table floors (
    id              uuid primary key,
    pg_id           uuid not null references pgs (id),
    name            varchar(120) not null,
    floor_number    int not null,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    created_by      uuid,
    updated_by      uuid,
    deleted_at      timestamptz
);

create index idx_floors_pg on floors (pg_id) where deleted_at is null;

create table rooms (
    id              uuid primary key,
    floor_id        uuid not null references floors (id),
    room_number     varchar(50) not null,
    sharing_count   int not null check (sharing_count >= 1),
    rent_per_bed    numeric(10, 2) not null check (rent_per_bed >= 0),
    room_type       varchar(20) not null default 'NON_AC' check (room_type in ('NON_AC', 'AC')),
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now(),
    created_by      uuid,
    updated_by      uuid,
    deleted_at      timestamptz
);

create index idx_rooms_floor on rooms (floor_id) where deleted_at is null;

create table beds (
    id          uuid primary key,
    room_id     uuid not null references rooms (id),
    label       varchar(50) not null,
    status      varchar(20) not null default 'AVAILABLE' check (status in ('AVAILABLE', 'OCCUPIED', 'MAINTENANCE')),
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    created_by  uuid,
    updated_by  uuid,
    deleted_at  timestamptz
);

create index idx_beds_room on beds (room_id) where deleted_at is null;
create index idx_beds_room_status on beds (room_id, status) where deleted_at is null;
