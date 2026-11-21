// API client. In demo mode it serves synthetic data so the portal can be shown
// without a backend; otherwise it calls the Thelivu API (contracts/openapi.yaml).
import { mockAlerts, mockPatients, mockProgress } from "./mock";
import type { Alert, Override, PatientSummary, Progress, Session } from "./types";

const API = (import.meta.env.VITE_API_BASE as string | undefined) ?? "http://localhost:8080";
const KEY = "thelivu.portal.session";

export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

export function loadSession(): Session | null {
  try {
    const raw = sessionStorage.getItem(KEY);
    return raw ? (JSON.parse(raw) as Session) : null;
  } catch {
    return null;
  }
}

export function saveSession(s: Session | null) {
  try {
    if (s) sessionStorage.setItem(KEY, JSON.stringify(s));
    else sessionStorage.removeItem(KEY);
  } catch {
    /* storage unavailable: session lives in memory only */
  }
}

async function call<T>(s: Session, method: string, path: string, body?: unknown): Promise<T> {
  const res = await fetch(API + path, {
    method,
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${s.token}` },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!res.ok) {
    let detail = res.statusText;
    try {
      const p = await res.json();
      detail = p.detail || p.title || detail;
    } catch { /* not JSON */ }
    throw new ApiError(res.status, detail);
  }
  return res.status === 204 ? (undefined as T) : ((await res.json()) as T);
}

export async function login(email: string, password: string): Promise<Session> {
  const res = await fetch(API + "/v1/auth/staff/login", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  if (!res.ok) throw new ApiError(res.status, "Sign-in failed. Check your email and password.");
  const j = await res.json();
  return { token: j.access_token, role: j.role, name: j.name, clinicId: j.clinic_id, demo: false };
}

export function demoSession(): Session {
  return { token: "demo", role: "clinician", name: "Dr. Demo (synthetic data)", clinicId: "demo", demo: true };
}

const demoOverrides = new Map<string, Override>();

export const api = {
  patients: async (s: Session): Promise<PatientSummary[]> =>
    s.demo ? mockPatients() : (await call<{ patients: PatientSummary[] }>(s, "GET", "/v1/patients")).patients,
  progress: async (s: Session, id: string, days = 30): Promise<Progress> =>
    s.demo ? mockProgress(id, days) : call<Progress>(s, "GET", `/v1/patients/${id}/progress?days=${days}`),
  alerts: async (s: Session): Promise<Alert[]> =>
    s.demo ? mockAlerts() : (await call<{ alerts: Alert[] | null }>(s, "GET", "/v1/alerts")).alerts ?? [],
  putOverride: async (s: Session, id: string, module: string, o: Override): Promise<void> => {
    if (s.demo) {
      demoOverrides.set(`${id}/${module}`, o);
      return;
    }
    return call<void>(s, "PUT", `/v1/patients/${id}/modules/${module}/override`, o);
  },
};
