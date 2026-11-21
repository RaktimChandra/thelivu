-- Development seed (synthetic only; never real participants).
alter role thelivu_app password 'thelivu-app-dev';
insert into clinics (id, name, city, plan) values
  ('11111111-1111-4111-8111-111111111111', 'SRM MCH&RC Psychiatry (dev)', 'Chennai', 'research');
-- password for both: thelivu-dev  (bcrypt cost 12)
insert into staff (clinic_id, email, name, role, password_hash) values
  ('11111111-1111-4111-8111-111111111111', 'clinician@dev.thelivu.in', 'Dev Clinician', 'clinician',
   '$2b$12$1XVTPhD527mpUcGKtYFd0OiH4UqNoS6LbxjU0h/FM40AFBpDdI8l.'),
  (null, 'admin@dev.thelivu.in', 'Dev Platform Admin', 'platform_admin',
   '$2b$12$1XVTPhD527mpUcGKtYFd0OiH4UqNoS6LbxjU0h/FM40AFBpDdI8l.');
