// Command api is the Thelivu backend (see docs/architecture/ARCHITECTURE.md).
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/RaktimChandra/thelivu/services/api/internal/config"
	"github.com/RaktimChandra/thelivu/services/api/internal/db"
	"github.com/RaktimChandra/thelivu/services/api/internal/server"
)

func main() {
	log := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	cfg, err := config.Load()
	if err != nil {
		log.Error("config", "err", err)
		os.Exit(1)
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	database, err := db.Open(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Error("database", "err", err)
		os.Exit(1)
	}
	defer database.Pool.Close()
	srv := &http.Server{
		Addr:              cfg.Addr,
		Handler:           server.New(cfg, database, log).Handler(),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       120 * time.Second,
	}
	go func() {
		log.Info("listening", "addr", cfg.Addr, "env", cfg.Env)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Error("serve", "err", err)
			stop()
		}
	}()
	<-ctx.Done()
	shutdown, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	_ = srv.Shutdown(shutdown)
	log.Info("stopped")
}
