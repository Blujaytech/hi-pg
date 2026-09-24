-- Harden room identity and complete the customer/property details required by
-- the booking, owner-review and discovery flows.

-- Preserve every existing room while making legacy duplicates distinguishable
-- before the new invariant is installed.
with ranked as (
    select id,
           row_number() over (
               partition by floor_id, lower(trim(room_number))
               order by created_at, id
           ) as duplicate_number
    from rooms
    where deleted_at is null
)
update rooms r
set room_number = left(trim(r.room_number), 34) || ' (duplicate ' || ranked.duplicate_number || ')'
from ranked
where r.id = ranked.id and ranked.duplicate_number > 1;

create unique index uq_rooms_floor_number_active
    on rooms (floor_id, lower(trim(room_number)))
    where deleted_at is null;

alter table customer_profiles
    add column guardian_name varchar(255),
    add column guardian_phone varchar(16);

alter table pgs
    add column photo_storage_key varchar(500);

alter table bookings
    add column check_out_time time;
