-- The pilot administrator uses the same email/password login endpoint as PG
-- owners. An upsert makes the designated credentials deterministic in both an
-- existing database (preserving its user id and owned PGs) and a fresh one.
-- The password is a BCrypt hash; plaintext is never stored in the database.
insert into users (id, email, password_hash, full_name, role, provider, status,
                   email_verified, phone_verified, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000001',
        'nazeerbasha0526@gmail.com',
        '$2a$12$ggZ/9e.Q/0JYlV2AW7h6qO.OpbdpQOTqhFx8eNQGY35z0MXMADhSa',
        'Nazeer Basha', 'ADMIN', 'LOCAL', 'ACTIVE', true, false, now(), now())
on conflict (email) do update
set password_hash = excluded.password_hash,
    role = 'ADMIN',
    provider = 'LOCAL',
    status = 'ACTIVE',
    email_verified = true,
    deleted_at = null,
    updated_at = now();
