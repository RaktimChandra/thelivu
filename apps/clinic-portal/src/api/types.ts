// Mirrors contracts/openapi.yaml (components.schemas).
export type Role = "platform_admin" | "clinic_admin" | "clinician";

export interface Session {
  token: string;
  role: Role;
  name: string;
  clinicId: string;
  demo: boolean;
}

export interface PatientSummary {
  id: string;
  thelivu_id: string;
  display_name: string;
  language: "en" | "ta" | "hi";
  status: string;
  study_arm: string | null;
  last_active: string | null;
  days_active_7: number;
  trials_today: number;
  signed_in_today: boolean;
  open_alerts: number;
}

export interface DayPoint {
  day: string;
  trials: number;
  sessions: number;
  accuracy: number | null;
  rt_median_ms: number | null;
  omissions: number;
  commissions: number;
  minutes: number;
  complete: boolean;
}

export interface ModulePoint {
  day: string;
  module_id: string;
  level_max: number;
  level_end: number;
  accuracy: number;
  rt_median_ms: number | null;
  trials: number;
}

export interface Progress {
  patient_id: string;
  days: DayPoint[];
  modules: ModulePoint[];
}

export interface Override {
  level?: number | null;
  locked: boolean;
  floor?: number | null;
  ceiling?: number | null;
  goal_scale?: number | null;
  reason: string;
}

export interface Alert {
  id: number;
  patient_id: string;
  display_name: string;
  kind: string;
  context: string;
  created_at: string;
}

export const MODULES: Record<string, { name: string; domain: string; levels: number }> = {
  d1_clerical_scan: { name: "Quick Find", domain: "Speed of processing", levels: 10 },
  d1_velocity_nback: { name: "Same as Before (n-back)", domain: "Speed of processing", levels: 10 },
  d1_speeded_sort: { name: "Sort It", domain: "Speed of processing", levels: 10 },
  d1_plate_check: { name: "Number Plate Check (alt.)", domain: "Speed of processing", levels: 10 },
};
