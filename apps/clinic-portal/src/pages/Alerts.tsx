import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api } from "../api/client";
import type { Alert, Session } from "../api/types";
import { ago } from "../lib/format";

export default function Alerts({ session }: { session: Session }) {
  const [rows, setRows] = useState<Alert[] | null>(null);
  const [error, setError] = useState("");
  useEffect(() => { api.alerts(session).then(setRows).catch((e) => setError(String(e.message ?? e))); }, [session]);
  return (
    <>
      <div className="head"><div><h1>Safety alerts</h1><div className="sub">Raised when a patient taps "I'm not feeling well". Follow your clinic's safety protocol.</div></div></div>
      {error && <div className="card msg err">{error}</div>}
      {rows && rows.length === 0 && <div className="card empty">No open alerts.</div>}
      {rows && rows.length > 0 && (
        <div className="card" style={{ padding: 0 }}>
          <table>
            <thead><tr><th>Patient</th><th>When</th><th>Where in the app</th></tr></thead>
            <tbody>{rows.map((a) => (
              <tr key={a.id}><td><Link to={`/patients/${a.patient_id}`}><b>{a.display_name}</b></Link></td><td>{ago(a.created_at)}</td><td className="mono">{a.context || "–"}</td></tr>
            ))}</tbody>
          </table>
        </div>
      )}
    </>
  );
}
