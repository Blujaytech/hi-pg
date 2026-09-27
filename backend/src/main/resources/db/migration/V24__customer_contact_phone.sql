-- A customer's booking contact is profile data, not an authentication
-- credential.  Keep it separate from users.phone so Google customers can
-- give the PG owner a number without pretending that it was OTP verified.
alter table customer_profiles
    add column contact_phone varchar(16);

update customer_profiles cp
set contact_phone = u.phone
from users u
where u.id = cp.user_id
  and cp.contact_phone is null
  and u.phone is not null;

alter table customer_profiles
    add constraint chk_customer_profile_contact_phone
        check (contact_phone is null or contact_phone ~ '^\+?[1-9][0-9]{9,14}$');
