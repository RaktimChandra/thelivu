import { describe, expect, it } from "vitest";
import { ago, overrideProblem, pct, secs, shortDay } from "./format";
import { mockPatients, mockProgress } from "../api/mock";

describe("format", () => {
  it("formats numbers", () => {
    expect(pct(0.786)).toBe("79%");
    expect(pct(null)).toBe("–");
    expect(secs(2345)).toBe("2.3 s");
    expect(shortDay("2026-11-21")).toBe("21/11");
    const now = new Date("2026-11-21T10:00:00Z");
    expect(ago("2026-11-21T07:00:00Z", now)).toBe("3 h ago");
    expect(ago("2026-11-20T08:00:00Z", now)).toBe("yesterday");
    expect(ago(null, now)).toBe("never");
  });
  it("validates overrides like the API", () => {
    expect(overrideProblem({ locked: true, reason: "tired" })).toMatch(/level to hold/);
    expect(overrideProblem({ locked: false, floor: 6, ceiling: 3, reason: "ok ok" })).toMatch(/lowest/);
    expect(overrideProblem({ locked: false, level: 4, reason: "x" })).toMatch(/reason/);
    expect(overrideProblem({ locked: true, level: 4, goal_scale: 1.25, reason: "Fatigue" })).toBe("");
  });
});

describe("synthetic data", () => {
  it("is deterministic and plausible", () => {
    const a = mockPatients(new Date("2026-11-21T10:00:00Z"));
    const b = mockPatients(new Date("2026-11-21T10:00:00Z"));
    expect(a).toEqual(b);
    expect(a).toHaveLength(12);
    const p = mockProgress(a[0].id, 30, new Date("2026-11-21T10:00:00Z"));
    expect(p.days.length).toBeGreaterThan(15);
    for (const d of p.days) {
      expect(d.accuracy!).toBeGreaterThan(0.5);
      expect(d.accuracy!).toBeLessThanOrEqual(0.95);
    }
    for (const m of p.modules) expect(m.level_end).toBeGreaterThanOrEqual(1);
  });
});
