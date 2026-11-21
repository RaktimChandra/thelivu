import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../api/client";
import type { PatientSummary, Session } from "../api/types";
import { Stat } from "../components/Stat";
import { ago } from "../lib/format";

const LANG = { en: "English", ta: "Tamil", hi: "Hindi" } as const;

export default function Patients({ session }: { session: Session }) {
  const [rows, setRows] = useState<PatientSummary[] | null>(null);
  const [error, setError] = useState("");
  const [q, setQ] = useState("");
  const nav = useNavigate();
  useEffect(() => {
    api.patients(session).then(setRows).catch((e) => setError(String(e.message ?? e)));
  }, [session]);
  const shown = useMemo(
    () => (rows ?? []).filter((p) => (p.display_name + p.thelivu_id).toLowerCase().includes(q.toLowerCase())),
    [rows, q],
  );
  if (error) return <div className="card msg err">Could not load patients: {error}</div>;
  if (!rows) return <div className="empty">Loading…</div>;
  const active = rows.filter((p) => p.status === "active");
  const signedIn = active.filter((p) => p.signed_in_today).length;
  const notSeen3 = active.filter((p) => !p.last_active || Date.now() - new Date(p.last_active).getTime() > 3 * 86400e3).length;
  const alerts = rows.reduce((a, p) => a + p.open_alerts, 0);
  return (
    <>
      <div className="head">
        <div><h1>Patients</h1><div className="sub">Today's sign-ins and training at a glance. Select a patient for progress and difficulty.</div></div>
        <input placeholder="Search name or Thelivu ID" value={q} onChange={(e) => setQ(e.target.value)} aria-label="Search patients" style={{ width: 260 }} />
      </div>
      <div className="cards">
        <Stat k="Active patients" v={active.length} n={`${rows.length - active.length} paused or withdrawn`} />
        <Stat k="Signed in today" v={`${signedIn} / ${active.length}`} n="Requirement R2" />
        <Stat k="Not seen for 3+ days" v={notSeen3} n="Consider a reminder call" warn={notSeen3 > 0} />
        <Stat k="Open safety alerts" v={alerts} n="'I'm not feeling well' presses" warn={alerts > 0} />
      </div>
      <div className="card" style={{ padding: 0, overflow: "auto" }}>
        <table>
          <thead>
            <tr><th>Patient</th><th>Thelivu ID</th><th>Today</th><th>Trials today</th><th>Last 7 days</th><th>Last active</th><th>Arm</th><th>Language</th></tr>
          </thead>
          <tbody>
            {shown.map((p) => (
              <tr key={p.id} className="row" tabIndex={0} onClick={() => nav(`/patients/${p.id}`)} onKeyDown={(e) => e.key === "Enter" && nav(`/patients/${p.id}`)}>
                <td><b>{p.display_name}</b> {p.open_alerts > 0 && <span className="pill alert">alert</span>} {p.status !== "active" && <span className="pill no">{p.status}</span>}</td>
                <td className="mono">{p.thelivu_id}</td>
                <td>{p.signed_in_today ? <span className="pill ok"><span className="dot" />signed in</span> : <span className="pill no">not yet</span>}</td>
                <td>{p.trials_today}</td>
                <td><span className="week" aria-label={`${p.days_active_7} of 7 days`}>{Array.from({ length: 7 }, (_, i) => <i key={i} className={i < p.days_active_7 ? "on" : ""} />)}</span> {p.days_active_7}/7</td>
                <td>{ago(p.last_active)}</td>
                <td style={{ textTransform: "capitalize" }}>{p.study_arm ?? "–"}</td>
                <td>{LANG[p.language]}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {shown.length === 0 && <div className="empty">No patients match.</div>}
      </div>
    </>
  );
}
