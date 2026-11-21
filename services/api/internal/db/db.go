// Package db opens the PostgreSQL pool and runs work inside tenant-scoped
// transactions. Row-level security policies read the settings set here, so a
// query can only ever see rows of the caller's clinic (ADR-0006).
package db

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/RaktimChandra/thelivu/services/api/internal/auth"
)

type DB struct{ Pool *pgxpool.Pool }

func Open(ctx context.Context, url string) (*DB, error) {
	cfg, err := pgxpool.ParseConfig(url)
	if err != nil {
		return nil, err
	}
	cfg.MaxConns = 20
	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, err
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping: %w", err)
	}
	return &DB{Pool: pool}, nil
}

// Tx runs fn in a transaction whose RLS context is the principal.
func (d *DB) Tx(ctx context.Context, p auth.Principal, fn func(pgx.Tx) error) error {
	tx, err := d.Pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if _, err := tx.Exec(ctx,
		`select set_config('app.role', $1, true), set_config('app.clinic_id', $2, true),
		        set_config('app.patient_id', $3, true), set_config('app.user_id', $4, true)`,
		p.Role, p.ClinicID, p.PatientID, p.Subject); err != nil {
		return err
	}
	if err := fn(tx); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// System is the principal used for pre-authentication lookups (sign-in).
// It can only call the SECURITY DEFINER login functions; RLS hides every table.
var System = auth.Principal{Role: "system"}
