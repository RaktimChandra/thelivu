// Package server wires routes to handlers. Every authenticated handler runs its
// database work through db.Tx with the caller's principal, so row-level
// security scopes every query to the caller's clinic or to the patient.
package server

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/RaktimChandra/thelivu/services/api/internal/auth"
	"github.com/RaktimChandra/thelivu/services/api/internal/config"
	"github.com/RaktimChandra/thelivu/services/api/internal/db"
	"github.com/RaktimChandra/thelivu/services/api/internal/httpx"
	"github.com/RaktimChandra/thelivu/services/api/internal/patients"
	"github.com/RaktimChandra/thelivu/services/api/internal/telemetry"
)

type Server struct {
	cfg config.Config
	db  *db.DB
	log *slog.Logger
	now func() time.Time
}

func New(cfg config.Config, d *db.DB, log *slog.Logger) *Server {
	return &Server{cfg: cfg, db: d, log: log, now: time.Now}
}

var (
	staffRoles   = []string{auth.RolePlatformAdmin, auth.RoleClinicAdmin, auth.RoleClinician}
	clinicRoles  = []string{auth.RoleClinicAdmin, auth.RoleClinician}
	patientRoles = []string{auth.RolePatient}
)

func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	req := func(roles []string, h http.HandlerFunc) http.HandlerFunc {
		return auth.Require(s.cfg.TokenSecret, roles, func(w http.ResponseWriter, r *http.Request, code int, msg string) {
			httpx.Problem(w, r, code, http.StatusText(code), msg)
		}, h)
	}
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) { httpx.JSON(w, 200, map[string]string{"status": "ok"}) })
	mux.HandleFunc("GET /readyz", s.ready)

	mux.HandleFunc("POST /v1/auth/patient/login", s.patientLogin)
	mux.HandleFunc("POST /v1/auth/staff/login", s.staffLogin)

	// Patient device
	mux.HandleFunc("POST /v1/telemetry/trials:batch", req(patientRoles, s.ingestTrials))
	mux.HandleFunc("PUT /v1/me/sessions/{id}", req(patientRoles, s.putSession))
	mux.HandleFunc("POST /v1/me/alerts", req(patientRoles, s.raiseAlert))
	mux.HandleFunc("GET /v1/me/overrides", req(patientRoles, s.myOverrides))

	// Clinic portal
	mux.HandleFunc("GET /v1/patients", req(staffRoles, s.listPatients))
	mux.HandleFunc("POST /v1/patients", req(clinicRoles, s.createPatient))
	mux.HandleFunc("GET /v1/patients/{id}/progress", req(staffRoles, s.progress))
	mux.HandleFunc("PUT /v1/patients/{id}/modules/{module}/override", req(clinicRoles, s.putOverride))
	mux.HandleFunc("GET /v1/alerts", req(clinicRoles, s.listAlerts))

	var h http.Handler = mux
	h = httpx.CORS(s.cfg.AllowedOrigins, h)
	h = httpx.Security(h)
	return httpx.Logging(s.log, h)
}

func (s *Server) ready(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	if err := s.db.Pool.Ping(ctx); err != nil {
		httpx.Problem(w, r, http.StatusServiceUnavailable, "Database unavailable", "")
		return
	}
	httpx.JSON(w, 200, map[string]string{"status": "ready"})
}

func (s *Server) fail(w http.ResponseWriter, r *http.Request, err error) {
	var pg *pgconn.PgError
	switch {
	case errors.Is(err, patients.ErrNotFound), errors.Is(err, pgx.ErrNoRows):
		httpx.Problem(w, r, http.StatusNotFound, "Not found", "")
	case errors.As(err, &pg) && pg.Code == "42501":
		httpx.Problem(w, r, http.StatusForbidden, "Forbidden", "row-level security denied this change")
	case errors.As(err, &pg) && pg.Code == "23505":
		httpx.Problem(w, r, http.StatusConflict, "Conflict", pg.ConstraintName)
	default:
		s.log.Error("handler", "request_id", httpx.RequestID(r.Context()), "err", err)
		httpx.Problem(w, r, http.StatusInternalServerError, "Internal error", "")
	}
}

// ---------------------------------------------------------------- auth

type patientLoginReq struct {
	ThelivuID string `json:"thelivu_id"`
	PIN       string `json:"pin"`
	DeviceID  string `json:"device_id"`
}

func (s *Server) patientLogin(w http.ResponseWriter, r *http.Request) {
	var in patientLoginReq
	if !httpx.Decode(w, r, &in) {
		return
	}
	id := auth.NormalizeID(in.ThelivuID)
	var pid, clinic, hash, status, lang, name string
	var locked *time.Time
	var ok bool
	err := s.db.Tx(r.Context(), db.System, func(tx pgx.Tx) error {
		err := tx.QueryRow(r.Context(), `select id, clinic_id, pin_hash, locked_until, status, language, display_name from auth_patient_lookup($1)`, id).
			Scan(&pid, &clinic, &hash, &locked, &status, &lang, &name)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil
		}
		if err != nil {
			return err
		}
		if locked != nil && locked.After(s.now()) {
			return nil
		}
		ok = status == "active" && auth.CheckSecret(hash, in.PIN)
		_, err = tx.Exec(r.Context(), `select auth_patient_result($1, $2)`, pid, ok)
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	if !ok {
		// One message for unknown ID, wrong PIN and lockout: no account probing.
		httpx.Problem(w, r, http.StatusUnauthorized, "Sign-in failed", "check the Thelivu ID and PIN, or ask your clinic")
		return
	}
	p := auth.Principal{Subject: pid, Role: auth.RolePatient, ClinicID: clinic, PatientID: pid}
	tok, err := auth.Issue(s.cfg.TokenSecret, p, s.cfg.PatientTTL, s.now())
	if err != nil {
		s.fail(w, r, err)
		return
	}
	httpx.JSON(w, 200, map[string]any{"access_token": tok, "patient_id": pid, "display_name": name, "language": lang})
}

type staffLoginReq struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

func (s *Server) staffLogin(w http.ResponseWriter, r *http.Request) {
	var in staffLoginReq
	if !httpx.Decode(w, r, &in) {
		return
	}
	var uid, role, hash, name string
	var clinic *string
	var locked *time.Time
	var ok bool
	err := s.db.Tx(r.Context(), db.System, func(tx pgx.Tx) error {
		err := tx.QueryRow(r.Context(), `select id, clinic_id, role, password_hash, locked_until, name from auth_staff_lookup($1)`,
			strings.ToLower(strings.TrimSpace(in.Email))).Scan(&uid, &clinic, &role, &hash, &locked, &name)
		if errors.Is(err, pgx.ErrNoRows) {
			return nil
		}
		if err != nil {
			return err
		}
		if locked != nil && locked.After(s.now()) {
			return nil
		}
		ok = auth.CheckSecret(hash, in.Password)
		_, err = tx.Exec(r.Context(), `select auth_staff_result($1, $2)`, uid, ok)
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	if !ok {
		httpx.Problem(w, r, http.StatusUnauthorized, "Sign-in failed", "")
		return
	}
	p := auth.Principal{Subject: uid, Role: role}
	if clinic != nil {
		p.ClinicID = *clinic
	}
	tok, err := auth.Issue(s.cfg.TokenSecret, p, s.cfg.TokenTTL, s.now())
	if err != nil {
		s.fail(w, r, err)
		return
	}
	httpx.JSON(w, 200, map[string]any{"access_token": tok, "role": role, "clinic_id": p.ClinicID, "name": name})
}

// ---------------------------------------------------------------- patient device

func (s *Server) ingestTrials(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.From(r.Context())
	var b telemetry.Batch
	if !httpx.Decode(w, r, &b) {
		return
	}
	if len(b.Trials) == 0 || len(b.Trials) > telemetry.MaxBatch {
		httpx.Problem(w, r, http.StatusUnprocessableEntity, "Invalid batch", "send 1 to 500 trials")
		return
	}
	if problems := b.Validate(s.now()); len(problems) > 0 {
		httpx.JSON(w, http.StatusUnprocessableEntity, map[string]any{"title": "Invalid trials", "status": 422, "problems": problems})
		return
	}
	var inserted int64
	err := s.db.Tx(r.Context(), p, func(tx pgx.Tx) error {
		var err error
		inserted, err = telemetry.Insert(r.Context(), tx, p.ClinicID, p.PatientID, &b)
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	httpx.JSON(w, 200, map[string]any{"accepted": len(b.Trials), "inserted": inserted, "duplicates": int64(len(b.Trials)) - inserted})
}

type sessionReq struct {
	StartedAt   time.Time  `json:"started_at"`
	EndedAt     *time.Time `json:"ended_at"`
	Minutes     float64    `json:"minutes"`
	Games       int        `json:"games"`
	Complete    bool       `json:"complete"`
	FocusDomain string     `json:"focus_domain"`
}

func (s *Server) putSession(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.From(r.Context())
	var in sessionReq
	if !httpx.Decode(w, r, &in) {
		return
	}
	if in.Minutes < 0 || in.Minutes > 600 || in.Games < 0 || in.Games > 200 {
		httpx.Problem(w, r, http.StatusUnprocessableEntity, "Invalid session", "minutes or games out of range")
		return
	}
	err := s.db.Tx(r.Context(), p, func(tx pgx.Tx) error {
		_, err := tx.Exec(r.Context(), `insert into sessions (id, clinic_id, patient_id, started_at, ended_at, minutes, games, complete, focus_domain)
			values ($1,$2,$3,$4,$5,$6,$7,$8,nullif($9,''))
			on conflict (id) do update set ended_at = excluded.ended_at, minutes = excluded.minutes,
			  games = excluded.games, complete = excluded.complete`,
			r.PathValue("id"), p.ClinicID, p.PatientID, in.StartedAt, in.EndedAt, in.Minutes, in.Games, in.Complete, in.FocusDomain)
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type alertReq struct {
	Kind    string `json:"kind"`
	Context string `json:"context"`
}

func (s *Server) raiseAlert(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.From(r.Context())
	var in alertReq
	if !httpx.Decode(w, r, &in) {
		return
	}
	if in.Kind != "not_well" {
		httpx.Problem(w, r, http.StatusUnprocessableEntity, "Invalid alert", "patients can raise kind=not_well")
		return
	}
	err := s.db.Tx(r.Context(), p, func(tx pgx.Tx) error {
		_, err := tx.Exec(r.Context(), `insert into alerts (clinic_id, patient_id, kind, context) values ($1,$2,$3,left($4, 120))`,
			p.ClinicID, p.PatientID, in.Kind, in.Context)
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	w.WriteHeader(http.StatusCreated)
}

func (s *Server) myOverrides(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.From(r.Context())
	var out map[string]patients.Override
	err := s.db.Tx(r.Context(), p, func(tx pgx.Tx) error {
		var err error
		out, err = patients.OverridesFor(r.Context(), tx, p.PatientID)
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	httpx.JSON(w, 200, map[string]any{"overrides": out})
}

// ---------------------------------------------------------------- clinic portal

func (s *Server) listPatients(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.From(r.Context())
	var list []patients.Summary
	err := s.db.Tx(r.Context(), p, func(tx pgx.Tx) error {
		var err error
		if list, err = patients.List(r.Context(), tx); err != nil {
			return err
		}
		return patients.Audit(r.Context(), tx, p.Subject, p.Role, p.ClinicID, "list", "patients", "*")
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	httpx.JSON(w, 200, map[string]any{"patients": list})
}

func (s *Server) createPatient(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.From(r.Context())
	var in patients.NewPatient
	if !httpx.Decode(w, r, &in) {
		return
	}
	dob, err := time.Parse("2006-01-02", in.DateOfBirth)
	switch {
	case len(strings.TrimSpace(in.DisplayName)) < 2:
		httpx.Problem(w, r, 422, "Invalid patient", "display_name is required")
		return
	case err != nil || dob.After(s.now()) || dob.Year() < 1900:
		httpx.Problem(w, r, 422, "Invalid patient", "date_of_birth must be YYYY-MM-DD")
		return
	case len(in.PIN) < 4 || len(in.PIN) > 6 || strings.Trim(in.PIN, "0123456789") != "":
		httpx.Problem(w, r, 422, "Invalid patient", "pin must be 4 to 6 digits")
		return
	}
	hash, err := auth.HashSecret(in.PIN)
	if err != nil {
		s.fail(w, r, err)
		return
	}
	var id, tid string
	for attempt := 0; attempt < 5; attempt++ {
		if tid, err = auth.NewThelivuID(in.DisplayName, dob); err != nil {
			break
		}
		err = s.db.Tx(r.Context(), p, func(tx pgx.Tx) error {
			var e error
			if id, e = patients.Create(r.Context(), tx, p.ClinicID, tid, hash, in, dob.Year()); e != nil {
				return e
			}
			return patients.Audit(r.Context(), tx, p.Subject, p.Role, p.ClinicID, "create", "patient", id)
		})
		var pg *pgconn.PgError
		if !(errors.As(err, &pg) && pg.Code == "23505") {
			break // success or a non-collision error
		}
	}
	if err != nil {
		s.fail(w, r, err)
		return
	}
	httpx.JSON(w, http.StatusCreated, map[string]string{"id": id, "thelivu_id": tid})
}

func (s *Server) progress(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.From(r.Context())
	days := 30
	if v, err := strconv.Atoi(r.URL.Query().Get("days")); err == nil && v >= 1 && v <= 365 {
		days = v
	}
	var out patients.Progress
	err := s.db.Tx(r.Context(), p, func(tx pgx.Tx) error {
		var err error
		if out, err = patients.GetProgress(r.Context(), tx, r.PathValue("id"), days); err != nil {
			return err
		}
		return patients.Audit(r.Context(), tx, p.Subject, p.Role, p.ClinicID, "read", "patient_progress", r.PathValue("id"))
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	httpx.JSON(w, 200, out)
}

func (s *Server) putOverride(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.From(r.Context())
	var in patients.Override
	if !httpx.Decode(w, r, &in) {
		return
	}
	if msg := in.Validate(); msg != "" {
		httpx.Problem(w, r, 422, "Invalid override", msg)
		return
	}
	pid, mod := r.PathValue("id"), r.PathValue("module")
	err := s.db.Tx(r.Context(), p, func(tx pgx.Tx) error {
		if err := patients.PutOverride(r.Context(), tx, p.ClinicID, pid, mod, p.Subject, in); err != nil {
			return err
		}
		return patients.Audit(r.Context(), tx, p.Subject, p.Role, p.ClinicID, "override:"+mod, "patient", pid)
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) listAlerts(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.From(r.Context())
	type alert struct {
		ID          int64     `json:"id"`
		PatientID   string    `json:"patient_id"`
		DisplayName string    `json:"display_name"`
		Kind        string    `json:"kind"`
		Context     string    `json:"context"`
		CreatedAt   time.Time `json:"created_at"`
	}
	var out []alert
	err := s.db.Tx(r.Context(), p, func(tx pgx.Tx) error {
		rows, err := tx.Query(r.Context(), `select a.id, a.patient_id, p.display_name, a.kind, a.context, a.created_at
			from alerts a join patients p on p.id = a.patient_id where a.acknowledged_at is null order by a.created_at desc limit 200`)
		if err != nil {
			return err
		}
		out, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (alert, error) {
			var a alert
			err := r.Scan(&a.ID, &a.PatientID, &a.DisplayName, &a.Kind, &a.Context, &a.CreatedAt)
			return a, err
		})
		return err
	})
	if err != nil {
		s.fail(w, r, err)
		return
	}
	httpx.JSON(w, 200, map[string]any{"alerts": out})
}
