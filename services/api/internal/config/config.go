// Package config loads service configuration from the environment.
package config

import (
	"errors"
	"os"
	"strings"
	"time"
)

type Config struct {
	Addr           string        // listen address, e.g. ":8080"
	DatabaseURL    string        // postgres://thelivu_app:...@host/db
	TokenSecret    []byte        // HMAC key for access tokens (>= 32 bytes)
	TokenTTL       time.Duration // staff token lifetime
	PatientTTL     time.Duration // patient token lifetime (devices stay signed in)
	AllowedOrigins []string       // CORS origins for the clinic portal
	Env            string        // dev | staging | prod
}

func Load() (Config, error) {
	c := Config{
		Addr:        env("THELIVU_ADDR", ":8080"),
		DatabaseURL: os.Getenv("THELIVU_DATABASE_URL"),
		TokenSecret: []byte(os.Getenv("THELIVU_TOKEN_SECRET")),
		TokenTTL:    durationEnv("THELIVU_TOKEN_TTL", 8*time.Hour),
		PatientTTL:  durationEnv("THELIVU_PATIENT_TOKEN_TTL", 30*24*time.Hour),
		Env:         env("THELIVU_ENV", "dev"),
	}
	if o := os.Getenv("THELIVU_ALLOWED_ORIGINS"); o != "" {
		c.AllowedOrigins = strings.Split(o, ",")
	}
	if c.DatabaseURL == "" {
		return c, errors.New("THELIVU_DATABASE_URL is required")
	}
	if len(c.TokenSecret) < 32 {
		return c, errors.New("THELIVU_TOKEN_SECRET must be at least 32 bytes")
	}
	return c, nil
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func durationEnv(k string, def time.Duration) time.Duration {
	if v := os.Getenv(k); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			return d
		}
	}
	return def
}
