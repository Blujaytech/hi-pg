alter table user_notifications
    drop constraint ck_user_notifications_category;

alter table user_notifications
    add constraint ck_user_notifications_category check (
        category in ('GENERAL', 'BOOKING', 'PAYMENT', 'COMPLAINT', 'PROPERTY',
                     'DISCOVERY', 'ACCOUNT', 'SUPPORT')
    );
