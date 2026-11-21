export function pct(v: number | null | undefined): string {
  return v == null ? "–" : `${Math.round(v * 100)}%`;
}

export function secs(ms: number | null | undefined): string {
  return ms == null ? "–" : `${(ms / 1000).toFixed(1)} s`;
}

export function ago(iso: string | null, now = new Date()): string {
  if (!iso) return "never";
  const h = (now.getTime() - new Date(iso).getTime()) / 3600e3;
  if (h < 1) return "within the hour";
  if (h < 24) return `${Math.floor(h)} h ago`;
  const d = Math.floor(h / 24);
  return d === 1 ? "yesterday" : `${d} days ago`;
}

export function shortDay(iso: string): string {
  const [, m, d] = iso.split("-");
  return `${d}/${m}`;
}

/** Validation mirrors the API (patients.Override.Validate). */
export function overrideProblem(o: {
  level?: number | null; locked: boolean; floor?: number | null; ceiling?: number | null; goal_scale?: number | null; reason: string;
}): string {
  const inRange = (v?: number | null) => v == null || (v >= 1 && v <= 50);
  if (!inRange(o.level) || !inRange(o.floor) || !inRange(o.ceiling)) return "Levels must be between 1 and 50.";
  if (o.floor != null && o.ceiling != null && o.floor > o.ceiling) return "The lowest level cannot be above the highest.";
  if (o.goal_scale != null && (o.goal_scale < 0.5 || o.goal_scale > 2)) return "Time goal scale must be between 0.5 and 2.";
  if (o.locked && o.level == null) return "Choose a level to hold.";
  if (o.reason.trim().length < 3) return "Add a short reason; it is kept in the audit trail.";
  return "";
}
