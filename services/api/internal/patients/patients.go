// Package patients holds clinic-side patient queries: roster, daily activity,
// per-game progression and clinician difficulty overrides (R10, R11, R13, R16).
// Every function runs inside an RLS-scoped transaction from db.Tx.
package patients

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
)

var ErrNotFound = errors.New("not found")

type Summary struct {
	ID            string     `json:"id"`
	ThelivuID     string     `json:"thelivu_id"`
	DisplayName   string     `json:"display_name"`
	Language      string     `json:"language"`
	Status        string     `json:"status"`
	StudyArm      *string    `json:"study_arm"`
	LastActive    *time.Time `json:"last_active"`
	DaysActive7   int        `json:"days_active_7"`
	TrialsToday   int        `json:"trials_today"`
	SignedInToday bool       `json:"signed_in_today"`
	OpenAlerts    int        `json:"open_alerts"`
}

func List(ctx context.Context, tx pgx.Tx) ([]Summary, error) {
	rows, err := tx.Query(ctx, `
		with today as (select (now() at time zone 'Asia/Kolkata')::date d)
		select p.id, p.thelivu_id, p.display_name, p.language, p.status, p.study_arm,
		       (select max(recorded_at) from trials t where t.patient_id = p.id),
		       (select count(*) from daily_activity a, today where a.patient_id = p.id and a.day > today.d - 7)::int,
		       coalesce((select a.trials from daily_activity a, today where a.patient_id = p.id and a.day = today.d), 0)::int,
		       exists (select 1 from daily_activity a, today where a.patient_id = p.id and a.day = today.d),
		       (select count(*) from alerts al where al.patient_id = p.id and al.acknowledged_at is null)::int
		from patients p order by p.display_name`)
	if err != nil {
		return nil, err
	}
	return pgx.CollectRows(rows, func(r pgx.CollectableRow) (Summary, error) {
		var s Summary
		err := r.Scan(&s.ID, &s.ThelivuID, &s.DisplayName, &s.Language, &s.Status, &s.StudyArm,
			&s.LastActive, &s.DaysActive7, &s.TrialsToday, &s.SignedInToday, &s.OpenAlerts)
		return s, err
	})
}

type NewPatient struct {
	DisplayName string `json:"display_name"`
	DateOfBirth string `json:"date_of_birth"` // YYYY-MM-DD; only the year is stored
	Sex         string `json:"sex"`
	Language    string `json:"language"`
	StudyArm    string `json:"study_arm"`
	PIN         string `json:"pin"`
}

func Create(ctx context.Context, tx pgx.Tx, clinicID, thelivuID, pinHash string, n NewPatient, birthYear int) (string, error) {
	var id string
	err := tx.QueryRow(ctx, `insert into patients (clinic_id, thelivu_id, display_name, birth_year, sex, language, study_arm, pin_hash)
		values ($1, $2, $3, $4, nullif($5, ''), coalesce(nullif($6, ''), 'ta'), nullif($7, ''), $8) returning id`,
		clinicID, thelivuID, n.DisplayName, birthYear, n.Sex, n.Language, n.StudyArm, pinHash).Scan(&id)
	return id, err
}

type Day struct {
	Day         string   `json:"day"`
	Trials      int      `json:"trials"`
	Sessions    int      `json:"sessions"`
	Accuracy    *float64 `json:"accuracy"`
	RTMedianMs  *float64 `json:"rt_median_ms"`
	Omissions   int      `json:"omissions"`
	Commissions int      `json:"commissions"`
	Minutes     float64  `json:"minutes"`
	Complete    bool     `json:"complete"`
}

type ModulePoint struct {
	Day        string   `json:"day"`
	ModuleID   string   `json:"module_id"`
	LevelMax   int      `json:"level_max"`
	LevelEnd   int      `json:"level_end"`
	Accuracy   float64  `json:"accuracy"`
	RTMedianMs *float64 `json:"rt_median_ms"`
	Trials     int      `json:"trials"`
}

type Progress struct {
	PatientID string        `json:"patient_id"`
	Days      []Day         `json:"days"`
	Modules   []ModulePoint `json:"modules"`
}

// GetProgress returns daily activity and per-game progression for the last n days.
func GetProgress(ctx context.Context, tx pgx.Tx, patientID string, days int) (Progress, error) {
	p := Progress{PatientID: patientID}
	var exists bool
	if err := tx.QueryRow(ctx, `select exists(select 1 from patients where id = $1)`, patientID).Scan(&exists); err != nil {
		return p, err
	}
	if !exists {
		return p, ErrNotFound
	}
	rows, err := tx.Query(ctx, `
		select a.day::text, a.trials::int, a.sessions::int, a.accuracy::float8, a.rt_median_ms::float8,
		       a.omissions::int, a.commissions::int,
		       coalesce((select sum(s.minutes) from sessions s where s.patient_id = a.patient_id
		                 and (s.started_at at time zone 'Asia/Kolkata')::date = a.day), 0)::float8,
		       coalesce((select bool_or(s.complete) from sessions s where s.patient_id = a.patient_id
		                 and (s.started_at at time zone 'Asia/Kolkata')::date = a.day), false)
		from daily_activity a
		where a.patient_id = $1 and a.day > (now() at time zone 'Asia/Kolkata')::date - $2::int
		order by a.day`, patientID, days)
	if err != nil {
		return p, err
	}
	p.Days, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (Day, error) {
		var d Day
		err := r.Scan(&d.Day, &d.Trials, &d.Sessions, &d.Accuracy, &d.RTMedianMs, &d.Omissions, &d.Commissions, &d.Minutes, &d.Complete)
		return d, err
	})
	if err != nil {
		return p, err
	}
	rows, err = tx.Query(ctx, `
		select (recorded_at at time zone 'Asia/Kolkata')::date::text as day, module_id,
		       max(level)::int, (array_agg(level order by recorded_at desc))[1]::int,
		       avg(correct::int)::float8,
		       (percentile_cont(0.5) within group (order by rt_ms) filter (where correct and rt_ms >= 150))::float8,
		       count(*)::int
		from trials
		where patient_id = $1 and not practice
		  and recorded_at > now() - make_interval(days => $2::int)
		group by 1, 2 order by 1, 2`, patientID, days)
	if err != nil {
		return p, err
	}
	p.Modules, err = pgx.CollectRows(rows, func(r pgx.CollectableRow) (ModulePoint, error) {
		var m ModulePoint
		err := r.Scan(&m.Day, &m.ModuleID, &m.LevelMax, &m.LevelEnd, &m.Accuracy, &m.RTMedianMs, &m.Trials)
		return m, err
	})
	return p, err
}

type Override struct {
	Level     *int     `json:"level"`
	Locked    bool     `json:"locked"`
	Floor     *int     `json:"floor"`
	Ceiling   *int     `json:"ceiling"`
	GoalScale *float64 `json:"goal_scale"`
	Reason    string   `json:"reason"`
}

func (o Override) Validate() string {
	in := func(v *int) bool { return v == nil || (*v >= 1 && *v <= 50) }
	switch {
	case !in(o.Level) || !in(o.Floor) || !in(o.Ceiling):
		return "levels must be between 1 and 50"
	case o.Floor != nil && o.Ceiling != nil && *o.Floor > *o.Ceiling:
		return "floor must not exceed ceiling"
	case o.GoalScale != nil && (*o.GoalScale < 0.5 || *o.GoalScale > 2.0):
		return "goal_scale must be between 0.5 and 2.0"
	case o.Locked && o.Level == nil:
		return "a locked override needs a level"
	case len(o.Reason) < 3:
		return "a reason is required (shown in the audit trail)"
	}
	return ""
}

func PutOverride(ctx context.Context, tx pgx.Tx, clinicID, patientID, moduleID, actor string, o Override) error {
	tag, err := tx.Exec(ctx, `insert into module_overrides (patient_id, module_id, clinic_id, level, locked, floor, ceiling, goal_scale, reason, set_by)
		select $1, $2, p.clinic_id, $4, $5, $6, $7, $8, $9, $10 from patients p where p.id = $1 and p.clinic_id = $3
		on conflict (patient_id, module_id) do update set level = excluded.level, locked = excluded.locked,
		  floor = excluded.floor, ceiling = excluded.ceiling, goal_scale = excluded.goal_scale,
		  reason = excluded.reason, set_by = excluded.set_by, set_at = now()`,
		patientID, moduleID, clinicID, o.Level, o.Locked, o.Floor, o.Ceiling, o.GoalScale, o.Reason, actor)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// Overrides for the signed-in patient's device (synced into the app's Store).
func OverridesFor(ctx context.Context, tx pgx.Tx, patientID string) (map[string]Override, error) {
	rows, err := tx.Query(ctx, `select module_id, level, locked, floor, ceiling, goal_scale::float8, reason
		from module_overrides where patient_id = $1`, patientID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]Override{}
	for rows.Next() {
		var id string
		var o Override
		if err := rows.Scan(&id, &o.Level, &o.Locked, &o.Floor, &o.Ceiling, &o.GoalScale, &o.Reason); err != nil {
			return nil, err
		}
		out[id] = o
	}
	return out, rows.Err()
}

// Audit appends to the audit trail (same transaction as the action).
func Audit(ctx context.Context, tx pgx.Tx, actorID, role, clinicID, action, entity, entityID string) error {
	var clinic any
	if clinicID != "" {
		clinic = clinicID
	}
	_, err := tx.Exec(ctx, `insert into audit_log (actor_id, actor_role, clinic_id, action, entity, entity_id) values ($1,$2,$3,$4,$5,$6)`,
		actorID, role, clinic, action, entity, entityID)
	return err
}
