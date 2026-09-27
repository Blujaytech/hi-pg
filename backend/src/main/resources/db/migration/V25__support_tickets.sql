-- Separate platform help/support from property complaints. A support ticket is
-- owned by the authenticated account and reviewed by an administrator.
create table support_tickets (
    id                  uuid primary key,
    requester_user_id   uuid not null references users (id),
    requester_role      varchar(20) not null check (requester_role in ('OWNER', 'STUDENT')),
    category            varchar(30) not null check (category in (
                            'ACCOUNT', 'BOOKING', 'PAYMENT', 'KYC_DOCUMENTS',
                            'TECHNICAL', 'OTHER'
                        )),
    subject             varchar(120) not null,
    description         text not null,
    status              varchar(20) not null default 'OPEN'
                            check (status in ('OPEN', 'IN_PROGRESS', 'RESOLVED')),
    admin_response      text,
    responded_by_user_id uuid references users (id),
    responded_at        timestamptz,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),
    created_by          uuid,
    updated_by          uuid,
    deleted_at          timestamptz
);

create index idx_support_tickets_requester
    on support_tickets (requester_user_id, created_at desc)
    where deleted_at is null;

create index idx_support_tickets_admin_queue
    on support_tickets (status, created_at desc)
    where deleted_at is null;
