# Thelivu API

A Go 1.24 service using the standard library's `net/http` and `pgx`, backed by PostgreSQL 15+ with row-level security. Design: [ADR-0006](../../docs/adr/0006-api-modular-monolith-rls.md). Contract: [`contracts/openapi.yaml`](../../contracts/openapi.yaml).

| Endpoint | Who | Purpose (startup requirement) |
| --- | --- | --- |
| `POST /v1/auth/patient/login` | patient app | Thelivu ID + PIN, lockout after 5 failures (R1, R5) |
| `POST /v1/auth/staff/login` | portal | Email + password |
| `POST /v1/telemetry/trials:batch` | patient | Idempotent trial upload (R4, R15) |
| `PUT /v1/me/sessions/{id}` | patient | Session minutes, games, completion (R2, R3) |
| `POST /v1/me/alerts` | patient | "I'm not feeling well" |
| `GET /v1/me/overrides` | patient | Clinician difficulty settings for the device (R16) |
| `GET /v1/patients` | staff | Roster with today's sign-in and activity (R2, R3, R10) |
| `POST /v1/patients` | clinic staff | Enrol a patient; generates the Thelivu ID from name + DOB (R1) |
| `GET /v1/patients/{id}/progress` | staff | Daily series and per-game progression (R11, R13) |
| `PUT /v1/patients/{id}/modules/{module}/override` | clinic staff | Change difficulty at any time (R16) |
| `GET /v1/alerts` | clinic staff | Open safety alerts |

**Security model**
- Each request runs in a transaction that sets `app.role`, `app.clinic_id` and `app.patient_id`.
- RLS policies on every tenant table use those values, so clinic B cannot read clinic A's rows even through a buggy query. The integration test proves this with a raw SQL probe.
- Sign-in uses narrow `SECURITY DEFINER` functions.
- Every clinician read and write is written to `audit_log`.

```bash
make test               # unit tests
make test-integration   # full flow against a real PostgreSQL (see integration_test.go)
THELIVU_DATABASE_URL=... THELIVU_TOKEN_SECRET=$(openssl rand -hex 32) make run
```
