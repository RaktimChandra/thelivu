import { useState } from "react";
import { Navigate, NavLink, Route, Routes } from "react-router-dom";
import { loadSession, saveSession } from "./api/client";
import type { Session } from "./api/types";
import Login from "./pages/Login";
import Patients from "./pages/Patients";
import PatientDetail from "./pages/PatientDetail";
import Alerts from "./pages/Alerts";

export default function App() {
  const [session, setSession] = useState<Session | null>(loadSession());
  const signIn = (s: Session) => { saveSession(s); setSession(s); };
  const signOut = () => { saveSession(null); setSession(null); };
  if (!session) return <Login onSignIn={signIn} />;
  return (
    <div className="shell">
      <aside className="side">
        <div className="brand">
          <img src="./icon.svg" alt="" />
          <div><b>Thelivu</b><small>Clinic portal</small></div>
        </div>
        <nav className="nav">
          <NavLink to="/patients">Patients</NavLink>
          <NavLink to="/alerts">Safety alerts</NavLink>
        </nav>
        <div className="who">
          {session.name}<br />
          <span style={{ textTransform: "capitalize" }}>{session.role.replace("_", " ")}</span><br />
          <button onClick={signOut}>Sign out</button>
        </div>
      </aside>
      <main className="main">
        {session.demo && <div className="demo-banner">Demo mode · all names and numbers are synthetic. No real participant data.</div>}
        <Routes>
          <Route path="/patients" element={<Patients session={session} />} />
          <Route path="/patients/:id" element={<PatientDetail session={session} />} />
          <Route path="/alerts" element={<Alerts session={session} />} />
          <Route path="*" element={<Navigate to="/patients" replace />} />
        </Routes>
      </main>
    </div>
  );
}
