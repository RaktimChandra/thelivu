# ADR-0006 · Go modular monolith with PostgreSQL row-level security

- Status: accepted · 2026-11-21
- Context: The platform is small (a few clinics at first) but must keep clinic data strictly separated and must stay auditable.
- Decision:
  - One Go service (standard library `net/http` plus `pgx`), split into internal packages per bounded context (auth, clinics, patients, telemetry, overrides, consent, audit).
  - PostgreSQL row-level security keyed on per-transaction settings.
  - The OpenAPI contract lives in `contracts/`.
- Consequences:
  - Simple deployment (one container) and strong isolation.
  - The service can be split later along package boundaries if load demands it.
