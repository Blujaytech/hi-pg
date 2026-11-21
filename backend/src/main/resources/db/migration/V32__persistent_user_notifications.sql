create table user_notifications (
    id uuid primary key,
    user_id uuid not null references users(id),
    title varchar(120) not null,
    message text not null,
    category varchar(24) not null,
    action_route varchar(255),
    read_at timestamptz,
    created_at timestamptz not null,
    updated_at timestamptz not null,
    created_by uuid,
    updated_by uuid,
    deleted_at timestamptz,
    constraint ck_user_notifications_category check (
        category in ('GENERAL', 'BOOKING', 'PAYMENT', 'COMPLAINT', 'PROPERTY', 'ACCOUNT', 'SUPPORT')
    ),
    constraint ck_user_notifications_action_route check (
        action_route is null or action_route like '/%'
    )
);

create index idx_user_notifications_user_created
    on user_notifications(user_id, created_at desc)
    where deleted_at is null;

create index idx_user_notifications_user_unread
    on user_notifications(user_id, created_at desc)
    where deleted_at is null and read_at is null;
