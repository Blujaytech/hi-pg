-- Stable Google identity used by the optional student sign-in method.
-- Email remains profile/contact data; authentication binds to Google's sub.
alter table users add column google_subject varchar(255);

create unique index uq_users_google_subject
    on users (google_subject)
    where google_subject is not null;
