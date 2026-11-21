drop view if exists daily_activity;
drop table if exists audit_log, alerts, module_overrides, trials, sessions, consents, patients, staff, clinics cascade;
drop function if exists auth_patient_lookup, auth_patient_result, auth_staff_lookup, auth_staff_result,
  app_is_staff_of, app_is_platform, app_patient, app_clinic, app_role;
