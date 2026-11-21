# Thelivu clinic portal

React 18, TypeScript and Vite, with Recharts. This is where clinicians and clinic admins see their patients:
- who signed in today, how much they trained, and whether they completed the session (R2, R3, R4, R10, R13);
- accuracy, response time, omission and commission errors, and level progression per game (R11, R15);
- difficulty adjustment with an audited reason (R16).

```bash
npm install
npm run dev                          # http://localhost:5173 ("Explore with synthetic demo data" works without a backend)
VITE_API_BASE=http://localhost:8080 npm run dev   # against the API (infra/docker-compose.yml)
npm run typecheck && npm test && npm run build
```

Demo mode uses deterministic synthetic data (`src/api/mock.ts`). There is never real participant data in this repository.
