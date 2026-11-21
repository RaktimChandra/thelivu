// Deterministic synthetic data for demos and tests. Never real participants.
import type { Alert, DayPoint, ModulePoint, PatientSummary, Progress } from "./types";

function rng(seed: number) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

const NAMES = ["Meena", "Karthik", "Lakshmi", "Suresh", "Divya", "Arun", "Priya", "Murugan", "Kavitha", "Rajesh", "Anitha", "Senthil"];

export function isoDay(d: Date): string {
  return d.toISOString().slice(0, 10);
}

export function mockPatients(today = new Date()): PatientSummary[] {
  const r = rng(7);
  return NAMES.map((name, i) => {
    const active = Math.floor(r() * 8);
    const signed = r() > 0.3;
    const last = new Date(today.getTime() - (signed ? r() * 6 : 24 + r() * 120) * 3600e3);
    const dd = String(1 + Math.floor(r() * 28)).padStart(2, "0");
    const mm = String(1 + Math.floor(r() * 12)).padStart(2, "0");
    return {
      id: `00000000-0000-4000-8000-${String(i + 1).padStart(12, "0")}`,
      thelivu_id: `${name.slice(0, 3).toUpperCase()}-${dd}${mm}-${"ACDEFGHJKM"[i % 10]}${"2346779"[(i * 3) % 7]}`,
      display_name: name,
      language: (["ta", "ta", "en", "hi"] as const)[i % 4],
      status: i === 9 ? "paused" : "active",
      study_arm: i % 2 === 0 ? "intervention" : "control",
      last_active: active === 0 && !signed ? null : last.toISOString(),
      days_active_7: signed ? Math.max(1, active) : active,
      trials_today: signed ? 20 + Math.floor(r() * 70) : 0,
      signed_in_today: signed,
      open_alerts: i === 3 ? 1 : 0,
    };
  });
}

const MODS = ["d1_clerical_scan", "d1_velocity_nback", "d1_speeded_sort"];

export function mockProgress(patientId: string, days = 30, today = new Date()): Progress {
  const seed = parseInt(patientId.slice(-4), 10) || 1;
  const r = rng(seed * 31);
  const dayPts: DayPoint[] = [];
  const modPts: ModulePoint[] = [];
  const level: Record<string, number> = { d1_clerical_scan: 2, d1_velocity_nback: 1, d1_speeded_sort: 2 };
  for (let k = days - 1; k >= 0; k--) {
    const d = isoDay(new Date(today.getTime() - k * 86400e3));
    if (r() < 0.22) continue; // missed day
    const t = (days - k) / days; // 0..1 over the period: gentle learning curve
    const minutes = Math.round(18 + r() * 30);
    const trials = Math.round(minutes * 2.6);
    const acc = Math.min(0.95, 0.66 + 0.14 * t + (r() - 0.5) * 0.08);
    dayPts.push({
      day: d, trials, sessions: 1, accuracy: acc,
      rt_median_ms: Math.round(4200 - 1300 * t + (r() - 0.5) * 500),
      omissions: Math.round(trials * (0.08 - 0.04 * t) + r() * 2),
      commissions: Math.round(trials * (0.12 - 0.05 * t) + r() * 2),
      minutes, complete: minutes >= 30,
    });
    for (const m of MODS) {
      if (r() < 0.25) continue;
      level[m] = Math.max(1, Math.min(10, level[m] + (r() < 0.55 + 0.1 * t ? 1 : r() < 0.6 ? 0 : -1)));
      modPts.push({
        day: d, module_id: m, level_end: level[m], level_max: level[m],
        accuracy: Math.min(0.97, 0.7 + 0.12 * t + (r() - 0.5) * 0.1),
        rt_median_ms: Math.round((m === "d1_clerical_scan" ? 5200 : 1100) * (1 - 0.25 * t) * (0.9 + r() * 0.2)),
        trials: 12 + Math.round(r() * 20),
      });
    }
  }
  return { patient_id: patientId, days: dayPts, modules: modPts };
}

export function mockAlerts(today = new Date()): Alert[] {
  return [{
    id: 1, patient_id: "00000000-0000-4000-8000-000000000004", display_name: "Suresh", kind: "not_well",
    context: "game:d1_velocity_nback", created_at: new Date(today.getTime() - 2.5 * 3600e3).toISOString(),
  }];
}
