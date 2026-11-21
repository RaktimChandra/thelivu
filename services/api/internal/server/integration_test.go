package server

// End-to-end test against a real PostgreSQL: migrations, row-level security,
// sign-in, telemetry ingestion, clinic isolation, overrides and alerts.
//
//   THELIVU_TEST_DATABASE_URL=postgres://postgres@127.0.0.1:55432/postgres go test ./internal/server -run Integration -v
//
// The URL must be a superuser on a throwaway database: the test recreates the schema.

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/RaktimChandra/thelivu/services/api/internal/auth"
	"github.com/RaktimChandra/thelivu/services/api/internal/config"
	"github.com/RaktimChandra/thelivu/services/api/internal/db"
)

func TestIntegration(t *testing.T) {
	ownerURL := os.Getenv("THELIVU_TEST_DATABASE_URL")
	if ownerURL == "" {
		t.Skip("THELIVU_TEST_DATABASE_URL not set")
	}
	ctx := context.Background()
	owner, err := pgx.Connect(ctx, ownerURL)
	if err != nil {
		t.Fatal(err)
	}
	defer owner.Close(ctx)
	up, _ := os.ReadFile("../../migrations/0001_init.up.sql")
	down, _ := os.ReadFile("../../migrations/0001_init.down.sql")
	_, _ = owner.Exec(ctx, string(down))
	if _, err := owner.Exec(ctx, string(up)); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	if _, err := owner.Exec(ctx, `alter role thelivu_app password 'app-test-pw'`); err != nil {
		t.Fatal(err)
	}
	// Seed two clinics, their admins and a platform admin.
	pw, _ := auth.HashSecret("correct horse battery")
	var clinicA, clinicB string
	must(t, owner.QueryRow(ctx, `insert into clinics (name, city) values ('SRM MCH&RC', 'Chennai') returning id`).Scan(&clinicA))
	must(t, owner.QueryRow(ctx, `insert into clinics (name, city) values ('Other Clinic', 'Madurai') returning id`).Scan(&clinicB))
	for _, s := range [][3]any{{clinicA, "a@srm.test", "clinic_admin"}, {clinicB, "b@other.test", "clinic_admin"}, {nil, "root@thelivu.test", "platform_admin"}} {
		_, err := owner.Exec(ctx, `insert into staff (clinic_id, email, name, role, password_hash) values ($1,$2,'Test',$3,$4)`, s[0], s[1], s[2], pw)
		must(t, err)
	}

	u, _ := url.Parse(ownerURL)
	u.User = url.UserPassword("thelivu_app", "app-test-pw")
	pool, err := pgxpool.New(ctx, u.String())
	must(t, err)
	defer pool.Close()
	cfg := config.Config{TokenSecret: []byte("integration-secret-integration-secret"), TokenTTL: time.Hour, PatientTTL: time.Hour}
	ts := httptest.NewServer(New(cfg, &db.DB{Pool: pool}, slog.New(slog.NewTextHandler(io.Discard, nil))).Handler())
	defer ts.Close()

	call := func(method, path, token string, body any) (int, map[string]any) {
		var rd io.Reader
		if body != nil {
			b, _ := json.Marshal(body)
			rd = bytes.NewReader(b)
		}
		req, _ := http.NewRequest(method, ts.URL+path, rd)
		req.Header.Set("Content-Type", "application/json")
		if token != "" {
			req.Header.Set("Authorization", "Bearer "+token)
		}
		res, err := http.DefaultClient.Do(req)
		must(t, err)
		defer res.Body.Close()
		out := map[string]any{}
		_ = json.NewDecoder(res.Body).Decode(&out)
		return res.StatusCode, out
	}
	login := func(email string) string {
		code, out := call("POST", "/v1/auth/staff/login", "", map[string]string{"email": email, "password": "correct horse battery"})
		if code != 200 {
			t.Fatalf("staff login %s: %d %v", email, code, out)
		}
		return out["access_token"].(string)
	}
	tokA, tokB, tokRoot := login("a@srm.test"), login("b@other.test"), login("root@thelivu.test")

	if code, _ := call("POST", "/v1/auth/staff/login", "", map[string]string{"email": "a@srm.test", "password": "wrong"}); code != 401 {
		t.Fatalf("wrong password accepted: %d", code)
	}

	// R1: clinic A enrols a patient; the ID is derived from name + DOB.
	code, created := call("POST", "/v1/patients", tokA, map[string]string{
		"display_name": "Meena", "date_of_birth": "1990-12-04", "pin": "2468", "language": "ta", "study_arm": "intervention"})
	if code != 201 || !strings.HasPrefix(created["thelivu_id"].(string), "MEE-0412-") {
		t.Fatalf("create patient: %d %v", code, created)
	}
	tid, pid := created["thelivu_id"].(string), created["id"].(string)
	if code, _ := call("POST", "/v1/patients", tokRoot, map[string]string{"display_name": "X", "date_of_birth": "1990-01-01", "pin": "1234"}); code != 403 {
		t.Fatalf("platform admin must not enrol into a clinic directly: %d", code)
	}

	// Patient signs in (case/dash-insensitive ID) and uploads trials twice (idempotent).
	code, pl := call("POST", "/v1/auth/patient/login", "", map[string]string{"thelivu_id": strings.ToLower(strings.ReplaceAll(tid, "-", "")), "pin": "2468"})
	if code != 200 {
		t.Fatalf("patient login: %d %v", code, pl)
	}
	tokP := pl["access_token"].(string)
	session := "8a7b6c5d-4e3f-4a1b-9c8d-7e6f5a4b3c2d"
	now := time.Now().UTC().Format(time.RFC3339)
	trial := func(id, outcome string, ok bool, rt int) map[string]any {
		return map[string]any{"event_id": id, "session_id": session, "module_id": "d1_clerical_scan", "module_version": "1.0.0",
			"theme_id": "bus", "level": 3, "index": 0, "practice": false, "outcome": outcome, "correct": ok, "rt_ms": rt,
			"t_onset_ms": 100, "soft_goal_ms": 10000, "stair_success": ok, "stimulus": map[string]any{"rows": 6},
			"response": map[string]any{"row": 2}, "recorded_at": now, "schema_version": "1.0"}
	}
	batch := map[string]any{"trials": []any{
		trial("3f1c2a4e-9b7d-4c1a-8e2f-1a2b3c4d5e6f", "correct", true, 2400),
		trial("4f1c2a4e-9b7d-4c1a-8e2f-1a2b3c4d5e6f", "omission", false, -1),
	}}
	if code, out := call("POST", "/v1/telemetry/trials:batch", tokP, batch); code != 200 || out["inserted"].(float64) != 2 {
		t.Fatalf("ingest: %d %v", code, out)
	}
	if code, out := call("POST", "/v1/telemetry/trials:batch", tokP, batch); code != 200 || out["duplicates"].(float64) != 2 {
		t.Fatalf("re-ingest should be idempotent: %d %v", code, out)
	}
	if code, _ := call("POST", "/v1/telemetry/trials:batch", tokA, batch); code != 403 {
		t.Fatalf("staff must not post patient telemetry: %d", code)
	}

	// Clinic isolation (RLS): A sees the patient, B does not, platform admin does.
	count := func(tok string) int {
		code, out := call("GET", "/v1/patients", tok, nil)
		if code != 200 {
			t.Fatalf("list: %d %v", code, out)
		}
		return len(out["patients"].([]any))
	}
	if a, b, root := count(tokA), count(tokB), count(tokRoot); a != 1 || b != 0 || root != 1 {
		t.Fatalf("isolation broken: A=%d B=%d root=%d", a, b, root)
	}
	if code, _ := call("GET", "/v1/patients/"+pid+"/progress", tokB, nil); code != 404 {
		t.Fatalf("clinic B read clinic A progress: %d", code)
	}
	code, prog := call("GET", "/v1/patients/"+pid+"/progress?days=7", tokA, nil)
	if code != 200 || len(prog["days"].([]any)) != 1 || len(prog["modules"].([]any)) != 1 {
		t.Fatalf("progress: %d %v", code, prog)
	}

	// R16: clinician override reaches the patient's device; B cannot set one.
	ov := map[string]any{"level": 4, "locked": true, "reason": "Fatigue this week; hold level"}
	if code, _ := call("PUT", "/v1/patients/"+pid+"/modules/d1_clerical_scan/override", tokB, ov); code != 404 {
		t.Fatalf("clinic B override on A's patient: %d", code)
	}
	if code, out := call("PUT", "/v1/patients/"+pid+"/modules/d1_clerical_scan/override", tokA, ov); code != 204 {
		t.Fatalf("override: %d %v", code, out)
	}
	if code, out := call("GET", "/v1/me/overrides", tokP, nil); code != 200 || out["overrides"].(map[string]any)["d1_clerical_scan"] == nil {
		t.Fatalf("my overrides: %d %v", code, out)
	}

	// Safety alert from the patient shows up for clinic A only.
	if code, _ := call("POST", "/v1/me/alerts", tokP, map[string]string{"kind": "not_well", "context": "game:d1_clerical_scan"}); code != 201 {
		t.Fatalf("alert: %d", code)
	}
	_, al := call("GET", "/v1/alerts", tokA, nil)
	_, bl := call("GET", "/v1/alerts", tokB, nil)
	if len(al["alerts"].([]any)) != 1 || bl["alerts"] != nil && len(bl["alerts"].([]any)) != 0 {
		t.Fatalf("alerts A=%v B=%v", al, bl)
	}

	// Belt and braces: even raw SQL as the app role with clinic B's context sees nothing.
	var n int
	err = (&db.DB{Pool: pool}).Tx(ctx, auth.Principal{Role: auth.RoleClinicAdmin, ClinicID: clinicB, Subject: "probe"}, func(tx pgx.Tx) error {
		return tx.QueryRow(ctx, `select count(*) from trials`).Scan(&n)
	})
	if err != nil || n != 0 {
		t.Fatalf("raw RLS probe: n=%d err=%v", n, err)
	}
	var audits int
	must(t, owner.QueryRow(ctx, `select count(*) from audit_log where clinic_id = $1`, clinicA).Scan(&audits))
	if audits < 3 {
		t.Fatalf("expected audit entries, got %d", audits)
	}
	fmt.Printf("integration ok: patient %s, %d audit entries\n", tid, audits)
}

func must(t *testing.T, err error) {
	t.Helper()
	if err != nil {
		t.Fatal(err)
	}
}
