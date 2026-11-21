import { FormEvent, useState } from "react";
import { demoSession, login } from "../api/client";
import type { Session } from "../api/types";

export default function Login({ onSignIn }: { onSignIn: (s: Session) => void }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      onSignIn(await login(email, password));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Sign-in failed.");
    } finally {
      setBusy(false);
    }
  }
  return (
    <div className="login">
      <form className="card" onSubmit={submit}>
        <div className="brand" style={{ padding: 0 }}>
          <img src="./icon.svg" alt="" width={40} height={40} />
          <div><h1 style={{ fontSize: 24 }}>Thelivu</h1><div className="sub" style={{ marginTop: 0 }}>Clinic portal</div></div>
        </div>
        <label>Email<input type="email" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} required /></label>
        <label>Password<input type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} required /></label>
        <button className="btn" disabled={busy}>{busy ? "Signing in…" : "Sign in"}</button>
        {error && <div className="msg err" role="alert">{error}</div>}
        <button type="button" className="btn ghost" onClick={() => onSignIn(demoSession())}>Explore with synthetic demo data</button>
        <div className="sub" style={{ fontSize: 12.5 }}>For authorised clinic staff. Access is logged. Research use in the SRM MCH&amp;RC / SCARF study.</div>
      </form>
    </div>
  );
}
