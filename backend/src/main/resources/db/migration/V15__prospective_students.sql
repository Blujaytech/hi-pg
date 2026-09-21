-- A customer with a temporary booking hold must not count as an active
-- resident until Razorpay confirms the payment.
alter table students drop constraint students_status_check;
alter table students add constraint students_status_check
    check (status in ('PROSPECTIVE', 'ACTIVE', 'MOVED_OUT'));
