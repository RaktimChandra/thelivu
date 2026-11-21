import { FormEvent, useEffect, useMemo, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { Bar, BarChart, CartesianGrid, Legend, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { api } from "../api/client";
import { MODULES, type Override, type PatientSummary, type Progress, type Session } from "../api/types";
import { Stat } from "../components/Stat";
import { overrideProblem, pct, secs, shortDay } from "../lib/format";

const C = { teal: "#1e7568", turmeric: "#d49a33", slate: "#4f6585", night: "#152f45", line: "#d2deda" };
const AXIS = { fontSize: 12, fill: "#4f625d" };

export default function PatientDetail({ session }: { session: Session }) {
  const { id = "" } = useParams();
  const [days, setDays] = useState(30);
  const [prog, setProg] = useState<Progress | null>(null);
  const [who, setWho] = useState<PatientSummary | null>(null);
  const [mod, setMod] = useState("d1_clerical_scan");
  const [error, setError] = useState("");
  useEffect(() => {
    setProg(null);
    api.progress(session, id, days).then(setProg).catch((e) => setError(String(e.message ?? e)));
    api.patients(session).then((ps) => setWho(ps.find((p) => p.id === id) ?? null)).catch(() => undefined);
  }, [session, id, days]);

  const daily = useMemo(() => (prog?.days ?? []).map((d) => ({
    ...d, label: shortDay(d.day), acc: d.accuracy == null ? null : Math.round(d.accuracy * 100),
    rt: d.rt_median_ms == null ? null : +(d.rt_median_ms / 1000).toFixed(2),
  })), [prog]);
  const perMod = useMemo(() => (prog?.modules ?? []).filter((m) => m.module_id === mod).map((m) => ({
    label: shortDay(m.day), level: m.level_end, acc: Math.round(m.accuracy * 100),
    rt: m.rt_median_ms == null ? null : +(m.rt_median_ms / 1000).toFixed(2),
  })), [prog, mod]);

  if (error) return <div className="card msg err">Could not load progress: {error}</div>;
  if (!prog) return <div className="empty">Loading…</div>;
  const d = prog.days;
  const sum = (f: (x: typeof d[number]) => number) => d.reduce((a, x) => a + f(x), 0);
  const first = d.slice(0, 5), last = d.slice(-5);
  const avg = (xs: typeof d, f: (x: typeof d[number]) => number | null) => {
    const v = xs.map(f).filter((x): x is number => x != null);
    return v.length ? v.reduce((a, b) => a + b, 0) / v.length : null;
  };
  const rtFirst = avg(first, (x) => x.rt_median_ms), rtLast = avg(last, (x) => x.rt_median_ms);
  const modsSeen = Array.from(new Set(prog.modules.map((m) => m.module_id)));

  return (
    <>
      <div className="head">
        <div>
          <div className="sub" style={{ marginBottom: 6 }}><Link to="/patients">Patients</Link> / {who?.display_name ?? "Patient"}</div>
          <h1>{who?.display_name ?? "Patient"} <span className="mono" style={{ fontSize: 15, color: "#4f625d" }}>{who?.thelivu_id}</span></h1>
        </div>
        <div className="tabs" role="group" aria-label="Period">
          {[14, 30, 90].map((n) => <button key={n} className={n === days ? "on" : ""} onClick={() => setDays(n)}>{n} days</button>)}
        </div>
      </div>
      <div className="cards">
        <Stat k="Days trained" v={`${d.length} / ${days}`} n={`${d.filter((x) => x.complete).length} complete sessions (≥30 min)`} />
        <Stat k="Minutes trained" v={Math.round(sum((x) => x.minutes))} n={`${Math.round(sum((x) => x.minutes) / Math.max(1, d.length))} min per training day`} />
        <Stat k="Accuracy (recent)" v={pct(avg(last, (x) => x.accuracy))} n={`from ${pct(avg(first, (x) => x.accuracy))} at the start`} />
        <Stat k="Typical response time" v={secs(rtLast)} n={rtFirst && rtLast ? `${Math.round((1 - rtLast / rtFirst) * 100)}% faster than at the start` : ""} />
      </div>
      <div className="grid2">
        <div className="card chart-card">
          <h3>Daily training time</h3><p className="sub">Minutes per day (R3, R13). Dark bars meet the 30-minute completion rule.</p>
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={daily} margin={{ left: -18, right: 8 }}>
              <CartesianGrid stroke={C.line} vertical={false} />
              <XAxis dataKey="label" tick={AXIS} minTickGap={14} /><YAxis tick={AXIS} />
              <Tooltip />
              <Bar dataKey="minutes" name="Minutes" radius={[4, 4, 0, 0]} fill={C.teal} isAnimationActive={false}
                shape={(p: any) => <rect x={p.x} y={p.y} width={p.width} height={p.height} rx={3} fill={p.payload.complete ? C.teal : "#9cc9bf"} />} />
            </BarChart>
          </ResponsiveContainer>
        </div>
        <div className="card chart-card">
          <h3>Accuracy and response time</h3><p className="sub">All games, per day (R15). Accuracy should sit near the 75–80% target.</p>
          <ResponsiveContainer width="100%" height={220}>
            <LineChart data={daily} margin={{ left: -18, right: 0 }}>
              <CartesianGrid stroke={C.line} vertical={false} />
              <XAxis dataKey="label" tick={AXIS} minTickGap={14} />
              <YAxis yAxisId="a" domain={[40, 100]} tick={AXIS} unit="%" />
              <YAxis yAxisId="r" orientation="right" tick={AXIS} unit="s" />
              <Tooltip /><Legend wrapperStyle={{ fontSize: 12 }} />
              <Line yAxisId="a" dataKey="acc" name="Accuracy %" stroke={C.teal} strokeWidth={2.5} dot={false} connectNulls />
              <Line yAxisId="r" dataKey="rt" name="Median RT (s)" stroke={C.turmeric} strokeWidth={2.5} dot={false} connectNulls />
            </LineChart>
          </ResponsiveContainer>
        </div>
        <div className="card chart-card">
          <h3>Errors</h3><p className="sub">Omissions (no answer) and commissions (wrong answer) per day.</p>
          <ResponsiveContainer width="100%" height={220}>
            <BarChart data={daily} margin={{ left: -18, right: 8 }}>
              <CartesianGrid stroke={C.line} vertical={false} />
              <XAxis dataKey="label" tick={AXIS} minTickGap={14} /><YAxis tick={AXIS} />
              <Tooltip /><Legend wrapperStyle={{ fontSize: 12 }} />
              <Bar dataKey="omissions" name="Omissions" stackId="e" fill={C.slate} isAnimationActive={false} />
              <Bar dataKey="commissions" name="Commissions" stackId="e" fill={C.turmeric} isAnimationActive={false} />
            </BarChart>
          </ResponsiveContainer>
        </div>
        <div className="card chart-card">
          <h3>Progression by game</h3><p className="sub">Level reached each day (R11).</p>
          <div className="tabs">{modsSeen.map((m) => <button key={m} className={m === mod ? "on" : ""} onClick={() => setMod(m)}>{MODULES[m]?.name ?? m}</button>)}</div>
          <ResponsiveContainer width="100%" height={180}>
            <LineChart data={perMod} margin={{ left: -18, right: 8 }}>
              <CartesianGrid stroke={C.line} vertical={false} />
              <XAxis dataKey="label" tick={AXIS} minTickGap={14} /><YAxis domain={[1, MODULES[mod]?.levels ?? 10]} allowDecimals={false} tick={AXIS} />
              <Tooltip />
              <Line type="stepAfter" dataKey="level" name="Level" stroke={C.night} strokeWidth={2.5} dot={{ r: 3 }} />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </div>
      <OverrideForm session={session} patientId={id} />
    </>
  );
}

function OverrideForm({ session, patientId }: { session: Session; patientId: string }) {
  const [module, setModule] = useState("d1_clerical_scan");
  const [o, setO] = useState<Override>({ level: null, locked: false, floor: null, ceiling: null, goal_scale: 1, reason: "" });
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const num = (v: string) => (v === "" ? null : Number(v));
  async function save(e: FormEvent) {
    e.preventDefault();
    const problem = overrideProblem(o);
    if (problem) return setMsg({ ok: false, text: problem });
    try {
      await api.putOverride(session, patientId, module, o);
      setMsg({ ok: true, text: `Saved. It reaches ${MODULES[module].name} on the patient's phone at the next sync.` });
    } catch (err) {
      setMsg({ ok: false, text: err instanceof Error ? err.message : "Could not save." });
    }
  }
  return (
    <form className="card" style={{ marginTop: 16 }} onSubmit={save}>
      <h2>Adjust difficulty</h2>
      <p className="sub" style={{ marginBottom: 14 }}>The game normally adapts by itself to keep success near 79%. Use this only with a clinical reason (R16); every change is audited.</p>
      <div className="form">
        <label>Game<select value={module} onChange={(e) => setModule(e.target.value)}>
          {Object.entries(MODULES).map(([k, m]) => <option key={k} value={k}>{m.name}</option>)}
        </select></label>
        <label>Set level<input type="number" min={1} max={10} value={o.level ?? ""} onChange={(e) => setO({ ...o, level: num(e.target.value) })} /></label>
        <label>Lowest level<input type="number" min={1} max={10} value={o.floor ?? ""} onChange={(e) => setO({ ...o, floor: num(e.target.value) })} /></label>
        <label>Highest level<input type="number" min={1} max={10} value={o.ceiling ?? ""} onChange={(e) => setO({ ...o, ceiling: num(e.target.value) })} /></label>
        <label>Time goal scale<select value={o.goal_scale ?? 1} onChange={(e) => setO({ ...o, goal_scale: Number(e.target.value) })}>
          {[0.75, 1, 1.25, 1.5, 2].map((v) => <option key={v} value={v}>{v === 1 ? "Standard" : v < 1 ? `${v}× (stricter)` : `${v}× (more time)`}</option>)}
        </select></label>
        <label className="check" style={{ alignSelf: "center" }}><input type="checkbox" checked={o.locked} onChange={(e) => setO({ ...o, locked: e.target.checked })} />Hold at this level</label>
        <label className="wide">Reason (kept in the audit trail)<input value={o.reason} onChange={(e) => setO({ ...o, reason: e.target.value })} placeholder="e.g. Fatigue reported this week; hold level for 7 days" /></label>
      </div>
      <div style={{ marginTop: 14, display: "flex", gap: 10, alignItems: "center" }}>
        <button className="btn">Save change</button>
        {msg && <span className={"msg " + (msg.ok ? "ok" : "err")} role="status">{msg.text}</span>}
      </div>
    </form>
  );
}
