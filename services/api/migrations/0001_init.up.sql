-- Thelivu schema v1 · PostgreSQL 15+
-- Tenancy: platform (startup) → clinics → patients. Every tenant table carries
-- clinic_id and is protected by row-level security (ADR-0006). The API connects
-- as role thelivu_app, which owns nothing and cannot bypass RLS.

create extension if not exists pgcrypto;
create extension if not exists citext;

-- ---------------------------------------------------------------- roles
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'thelivu_app') then
    create role thelivu_app login;
  end if;
end $$;

-- ---------------------------------------------------------------- RLS context helpers
create or replace function app_role() returns text language sql stable as
  $$ select coalesce(nullif(current_setting('app.role', true), ''), 'none') $$;
create or replace function app_clinic() returns uuid language sql stable as
  $$ select nullif(current_setting('app.clinic_id', true), '')::uuid $$;
create or replace function app_patient() returns uuid language sql stable as
  $$ select nullif(current_setting('app.patient_id', true), '')::uuid $$;
create or replace function app_is_platform() returns boolean language sql stable as
  $$ select app_role() = 'platform_admin' $$;
create or replace function app_is_staff_of(c uuid) returns boolean language sql stable as
  $$ select app_role() in ('clinic_admin', 'clinician') and c = app_clinic() $$;

-- ---------------------------------------------------------------- tables
create table clinics (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  city        text not null default '',
  plan        text not null default 'trial' check (plan in ('trial', 'standard', 'research')),
  status      text not null default 'active' check (status in ('active', 'suspended', 'closed')),
  created_at  timestamptz not null default now()
);

create table staff (
  id             uuid primary key default gen_random_uuid(),
  clinic_id      uuid references clinics(id),            -- null = platform admin
  email          citext unique not null,
  name           text not null,
  role           text not null check (role in ('platform_admin', 'clinic_admin', 'clinician')),
  password_hash  text not null,
  failed_logins  int not null default 0,
  locked_until   timestamptz,
  created_at     timestamptz not null default now(),
  check ((role = 'platform_admin') = (clinic_id is null))
);

create table patients (
  id               uuid primary key default gen_random_uuid(),
  clinic_id        uuid not null references clinics(id),
  thelivu_id       text unique not null,                  -- R1: e.g. MEE-0412-K7
  display_name     text not null,
  birth_year       smallint check (birth_year between 1900 and 2100),
  sex              text check (sex in ('female', 'male', 'other', 'undisclosed')),
  language         text not null default 'ta' check (language in ('en', 'ta', 'hi')),
  study_arm        text check (study_arm in ('intervention', 'control', 'none')),
  pin_hash         text not null,
  failed_logins    int not null default 0,
  locked_until     timestamptz,
  status           text not null default 'active' check (status in ('active', 'paused', 'withdrawn')),
  clinician_id     uuid references staff(id),
  created_at       timestamptz not null default now()
);
create index on patients (clinic_id);

-- Consent per purpose (DPDP Act 2023). Latest row per (patient, purpose) wins.
create table consents (
  id           bigserial primary key,
  clinic_id    uuid not null references clinics(id),
  patient_id   uuid not null references patients(id),
  purpose      text not null check (purpose in ('care', 'research', 'product_improvement', 'model_training')),
  granted      boolean not null,
  version      text not null,
  recorded_by  uuid,
  recorded_at  timestamptz not null default now()
);
create index on consents (patient_id, purpose, recorded_at desc);

create table sessions (
  id           uuid primary key,
  clinic_id    uuid not null references clinics(id),
  patient_id   uuid not null references patients(id),
  started_at   timestamptz not null,
  ended_at     timestamptz,
  minutes      numeric(6,2) not null default 0,
  games        int not null default 0,
  complete     boolean not null default false,
  focus_domain text
);
create index on sessions (patient_id, started_at desc);

-- One row per trial (contracts/schemas/trial-event.schema.json).
create table trials (
  event_id        uuid primary key,
  clinic_id       uuid not null references clinics(id),
  patient_id      uuid not null references patients(id),
  session_id      uuid not null,
  module_id       text not null,
  module_version  text not null,
  theme_id        text not null,
  level           int not null,
  idx             int not null,
  practice        boolean not null,
  outcome         text not null check (outcome in ('correct', 'wrong', 'omission', 'hit', 'miss', 'false_alarm', 'correct_reject')),
  correct         boolean not null,
  rt_ms           int,
  t_onset_ms      int,
  soft_goal_ms    int,
  stair_success   boolean,
  stimulus        jsonb not null default '{}',
  response        jsonb not null default '{}',
  recorded_at     timestamptz not null,
  received_at     timestamptz not null default now(),
  schema_version  text not null
);
create index on trials (patient_id, recorded_at desc);
create index on trials (clinic_id, recorded_at desc);
create index on trials (patient_id, module_id, recorded_at desc);

-- R16: clinician difficulty overrides per patient and module.
create table module_overrides (
  patient_id  uuid not null references patients(id),
  module_id   text not null,
  clinic_id   uuid not null references clinics(id),
  level       int,
  locked      boolean not null default false,
  floor       int,
  ceiling     int,
  goal_scale  numeric(4,2) check (goal_scale between 0.5 and 2.0),
  reason      text not null default '',
  set_by      uuid not null,
  set_at      timestamptz not null default now(),
  primary key (patient_id, module_id),
  check (floor is null or ceiling is null or floor <= ceiling)
);

-- "I'm not feeling well" presses and other signals for the care team.
create table alerts (
  id               bigserial primary key,
  clinic_id        uuid not null references clinics(id),
  patient_id       uuid not null references patients(id),
  kind             text not null check (kind in ('not_well', 'missed_days', 'performance_drop')),
  context          text not null default '',
  created_at       timestamptz not null default now(),
  acknowledged_by  uuid,
  acknowledged_at  timestamptz
);
create index on alerts (clinic_id, acknowledged_at nulls first, created_at desc);

-- Append-only audit trail of reads and writes of patient data.
create table audit_log (
  id          bigserial primary key,
  at          timestamptz not null default now(),
  actor_id    text not null,
  actor_role  text not null,
  clinic_id   uuid,
  action      text not null,
  entity      text not null,
  entity_id   text not null,
  detail      jsonb not null default '{}'
);
create index on audit_log (clinic_id, at desc);

-- R2/R3/R4/R13: one row per patient per day (Asia/Kolkata), computed from data.
create view daily_activity with (security_invoker = true) as
select t.clinic_id, t.patient_id,
       (t.recorded_at at time zone 'Asia/Kolkata')::date as day,
       count(*) filter (where not t.practice)                         as trials,
       count(distinct t.session_id)                                    as sessions,
       count(distinct t.module_id)                                     as modules,
       avg(t.correct::int) filter (where not t.practice)               as accuracy,
       percentile_cont(0.5) within group (order by t.rt_ms) filter (where t.correct and t.rt_ms >= 150) as rt_median_ms,
       count(*) filter (where t.outcome in ('omission', 'miss'))       as omissions,
       count(*) filter (where t.outcome in ('wrong', 'false_alarm'))   as commissions
from trials t
group by 1, 2, 3;

-- ---------------------------------------------------------------- row-level security
alter table clinics          enable row level security;
alter table staff            enable row level security;
alter table patients         enable row level security;
alter table consents         enable row level security;
alter table sessions         enable row level security;
alter table trials           enable row level security;
alter table module_overrides enable row level security;
alter table alerts           enable row level security;
alter table audit_log        enable row level security;

create policy clinics_read on clinics for select
  using (app_is_platform() or id = app_clinic());
create policy clinics_admin on clinics for all
  using (app_is_platform()) with check (app_is_platform());

create policy staff_read on staff for select
  using (app_is_platform() or app_is_staff_of(clinic_id));
create policy staff_write on staff for all
  using (app_is_platform() or (app_role() = 'clinic_admin' and clinic_id = app_clinic()))
  with check (app_is_platform() or (app_role() = 'clinic_admin' and clinic_id = app_clinic() and role <> 'platform_admin'));

create policy patients_staff on patients for all
  using (app_is_platform() or app_is_staff_of(clinic_id))
  with check (app_is_platform() or app_is_staff_of(clinic_id));
create policy patients_self on patients for select
  using (app_role() = 'patient' and id = app_patient());

-- Same pattern for patient-owned tables: staff of the clinic, platform admin, or the patient themself.
do $$
declare t text;
begin
  foreach t in array array['consents', 'sessions', 'trials', 'module_overrides', 'alerts'] loop
    execute format($f$
      create policy %1$s_staff on %1$s for all
        using (app_is_platform() or app_is_staff_of(clinic_id))
        with check (app_is_platform() or app_is_staff_of(clinic_id));
      create policy %1$s_self_read on %1$s for select
        using (app_role() = 'patient' and patient_id = app_patient());
    $f$, t);
  end loop;
end $$;

-- Patients may write their own play data and alerts, never overrides or consents.
create policy sessions_self_write on sessions for insert
  with check (app_role() = 'patient' and patient_id = app_patient() and clinic_id = app_clinic());
create policy sessions_self_update on sessions for update
  using (app_role() = 'patient' and patient_id = app_patient())
  with check (app_role() = 'patient' and patient_id = app_patient() and clinic_id = app_clinic());
create policy trials_self_write on trials for insert
  with check (app_role() = 'patient' and patient_id = app_patient() and clinic_id = app_clinic());
create policy alerts_self_write on alerts for insert
  with check (app_role() = 'patient' and patient_id = app_patient() and clinic_id = app_clinic());

create policy audit_insert on audit_log for insert with check (app_role() <> 'none');
create policy audit_read on audit_log for select
  using (app_is_platform() or (app_role() = 'clinic_admin' and clinic_id = app_clinic()));

-- ---------------------------------------------------------------- sign-in (pre-auth) functions
-- Sign-in happens before we know the clinic, so these narrow SECURITY DEFINER
-- functions are the only way in. They return what verification needs and nothing else.
create or replace function auth_patient_lookup(p_thelivu_id text)
returns table (id uuid, clinic_id uuid, pin_hash text, locked_until timestamptz, status text, language text, display_name text)
language sql security definer set search_path = public as $$
  select p.id, p.clinic_id, p.pin_hash, p.locked_until, p.status, p.language, p.display_name
  from patients p join clinics c on c.id = p.clinic_id
  where p.thelivu_id = p_thelivu_id and c.status = 'active'
$$;

create or replace function auth_patient_result(p_id uuid, p_ok boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_ok then
    update patients set failed_logins = 0, locked_until = null where id = p_id;
  else
    update patients set failed_logins = failed_logins + 1,
      locked_until = case when failed_logins + 1 >= 5 then now() + interval '15 minutes' else locked_until end
    where id = p_id;
  end if;
end $$;

create or replace function auth_staff_lookup(p_email text)
returns table (id uuid, clinic_id uuid, role text, password_hash text, locked_until timestamptz, name text)
language sql security definer set search_path = public as $$
  select s.id, s.clinic_id, s.role, s.password_hash, s.locked_until, s.name
  from staff s left join clinics c on c.id = s.clinic_id
  where s.email = p_email and (s.clinic_id is null or c.status = 'active')
$$;

create or replace function auth_staff_result(p_id uuid, p_ok boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_ok then
    update staff set failed_logins = 0, locked_until = null where id = p_id;
  else
    update staff set failed_logins = failed_logins + 1,
      locked_until = case when failed_logins + 1 >= 5 then now() + interval '15 minutes' else locked_until end
    where id = p_id;
  end if;
end $$;

revoke all on function auth_patient_lookup, auth_patient_result, auth_staff_lookup, auth_staff_result from public;

-- ---------------------------------------------------------------- grants
grant usage on schema public to thelivu_app;
grant select, insert, update, delete on all tables in schema public to thelivu_app;
grant usage on all sequences in schema public to thelivu_app;
revoke delete on audit_log from thelivu_app;
revoke update on audit_log from thelivu_app;
grant execute on function auth_patient_lookup, auth_patient_result, auth_staff_lookup, auth_staff_result,
  app_role, app_clinic, app_patient, app_is_platform, app_is_staff_of to thelivu_app;
