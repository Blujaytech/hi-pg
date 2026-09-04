-- V11: device tokens for push notifications (technical plan §6 Phase 13:
-- "push first -- cheapest, fastest feedback loop"). Actually sending a push
-- still needs a real FCM project/service account, which isn't provisioned
-- -- see NotificationGateway / LoggingNotificationGateway and
-- docs/decisions.md ADR-0020. This table exists so registration works
-- end-to-end regardless.

create table device_tokens (
    id           uuid primary key,
    user_id      uuid not null references users (id),
    token        varchar(500) not null,
    platform     varchar(10) not null check (platform in ('ANDROID', 'IOS', 'WEB')),
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now(),
    created_by   uuid,
    updated_by   uuid,
    deleted_at   timestamptz
);

create unique index uq_device_tokens_token on device_tokens (token) where deleted_at is null;
create index idx_device_tokens_user on device_tokens (user_id) where deleted_at is null;
