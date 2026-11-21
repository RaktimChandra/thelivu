// Package telemetry ingests trial events from the patient app (contract:
// contracts/schemas/trial-event.schema.json). Ingestion is idempotent on
// event_id, so the offline queue can safely resend a batch.
package telemetry

import (
	"context"
	"encoding/json"
	"fmt"
	"regexp"
	"time"

	"github.com/jackc/pgx/v5"
)

const MaxBatch = 500

var (
	uuidRe   = regexp.MustCompile(`^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`)
	moduleRe = regexp.MustCompile(`^d[1-7]_[a-z0-9_]{2,40}$`)
	outcomes = map[string]bool{"correct": true, "wrong": true, "omission": true, "hit": true, "miss": true, "false_alarm": true, "correct_reject": true}
)

type Trial struct {
	EventID       string          `json:"event_id"`
	SessionID     string          `json:"session_id"`
	ModuleID      string          `json:"module_id"`
	ModuleVersion string          `json:"module_version"`
	ThemeID       string          `json:"theme_id"`
	Level         int             `json:"level"`
	Index         int             `json:"index"`
	Practice      bool            `json:"practice"`
	Outcome       string          `json:"outcome"`
	Correct       bool            `json:"correct"`
	RTms          int             `json:"rt_ms"`
	TOnsetMs      int             `json:"t_onset_ms"`
	SoftGoalMs    int             `json:"soft_goal_ms"`
	StairSuccess  bool            `json:"stair_success"`
	Stimulus      json.RawMessage `json:"stimulus"`
	Response      json.RawMessage `json:"response"`
	RecordedAt    string          `json:"recorded_at"`
	SchemaVersion string          `json:"schema_version"`
}

type Batch struct {
	Trials []Trial `json:"trials"`
}

// Validate checks one trial; it returns a human-readable problem or "".
func (t *Trial) Validate(now time.Time) string {
	switch {
	case !uuidRe.MatchString(t.EventID):
		return "event_id must be a UUID"
	case !uuidRe.MatchString(t.SessionID):
		return "session_id must be a UUID"
	case !moduleRe.MatchString(t.ModuleID):
		return "module_id is not a valid module id"
	case t.ModuleVersion == "" || t.ThemeID == "":
		return "module_version and theme_id are required"
	case t.Level < 1 || t.Level > 50:
		return "level out of range"
	case t.Index < 0 || t.Index > 100000:
		return "index out of range"
	case !outcomes[t.Outcome]:
		return "unknown outcome"
	case t.RTms < -1 || t.RTms > 600000:
		return "rt_ms out of range"
	case t.SchemaVersion == "" || t.SchemaVersion[0] != '1':
		return "unsupported schema_version"
	}
	at, err := time.Parse(time.RFC3339, t.RecordedAt)
	if err != nil {
		return "recorded_at must be RFC 3339"
	}
	if at.After(now.Add(10*time.Minute)) || at.Before(now.AddDate(-1, 0, 0)) {
		return "recorded_at outside the accepted window"
	}
	if len(t.Stimulus) > 4096 || len(t.Response) > 4096 {
		return "stimulus/response too large"
	}
	return ""
}

// Validate a whole batch; problems are keyed by position.
func (b *Batch) Validate(now time.Time) map[int]string {
	out := map[int]string{}
	for i := range b.Trials {
		if p := b.Trials[i].Validate(now); p != "" {
			out[i] = p
		}
	}
	return out
}

func orEmpty(r json.RawMessage) []byte {
	if len(r) == 0 || string(r) == "null" {
		return []byte("{}")
	}
	return r
}

// Insert stores the batch for one patient inside an RLS-scoped transaction.
// Returns how many rows were new (duplicates are ignored).
func Insert(ctx context.Context, tx pgx.Tx, clinicID, patientID string, b *Batch) (int64, error) {
	batch := &pgx.Batch{}
	for _, t := range b.Trials {
		rt := &t.RTms
		if t.RTms < 0 {
			rt = nil
		}
		batch.Queue(`insert into trials (event_id, clinic_id, patient_id, session_id, module_id, module_version,
			theme_id, level, idx, practice, outcome, correct, rt_ms, t_onset_ms, soft_goal_ms, stair_success,
			stimulus, response, recorded_at, schema_version)
			values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20)
			on conflict (event_id) do nothing`,
			t.EventID, clinicID, patientID, t.SessionID, t.ModuleID, t.ModuleVersion, t.ThemeID, t.Level, t.Index,
			t.Practice, t.Outcome, t.Correct, rt, t.TOnsetMs, t.SoftGoalMs, t.StairSuccess,
			orEmpty(t.Stimulus), orEmpty(t.Response), t.RecordedAt, t.SchemaVersion)
	}
	res := tx.SendBatch(ctx, batch)
	defer res.Close()
	var n int64
	for range b.Trials {
		tag, err := res.Exec()
		if err != nil {
			return n, fmt.Errorf("insert trial: %w", err)
		}
		n += tag.RowsAffected()
	}
	return n, nil
}
