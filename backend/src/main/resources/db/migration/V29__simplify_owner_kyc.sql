alter table owner_kyc_submissions
    alter column pan_last_four drop not null,
    alter column aadhaar_last_four drop not null;
