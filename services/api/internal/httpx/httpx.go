// Package httpx holds JSON helpers, RFC 9457 problem responses and middleware.
package httpx

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"slices"
	"time"
)

type ctxKey int

const requestIDKey ctxKey = 1

// MaxBody caps request bodies (a full day's trials is ~1 MB).
const MaxBody = 4 << 20

func JSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

// Problem writes an RFC 9457 problem+json response.
func Problem(w http.ResponseWriter, r *http.Request, status int, title, detail string) {
	w.Header().Set("Content-Type", "application/problem+json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"type": "about:blank", "title": title, "status": status, "detail": detail,
		"instance": r.URL.Path, "request_id": RequestID(r.Context()),
	})
}

// Decode reads a JSON body strictly (unknown fields rejected).
func Decode(w http.ResponseWriter, r *http.Request, dst any) bool {
	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, MaxBody))
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		var mbe *http.MaxBytesError
		if errors.As(err, &mbe) {
			Problem(w, r, http.StatusRequestEntityTooLarge, "Body too large", err.Error())
		} else {
			Problem(w, r, http.StatusBadRequest, "Invalid JSON", err.Error())
		}
		return false
	}
	return true
}

func RequestID(ctx context.Context) string {
	if v, ok := ctx.Value(requestIDKey).(string); ok {
		return v
	}
	return ""
}

// Middleware chain ----------------------------------------------------------

type statusWriter struct {
	http.ResponseWriter
	status int
}

func (s *statusWriter) WriteHeader(code int) { s.status = code; s.ResponseWriter.WriteHeader(code) }

func Logging(log *slog.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := r.Header.Get("X-Request-ID")
		if id == "" {
			b := make([]byte, 8)
			_, _ = rand.Read(b)
			id = hex.EncodeToString(b)
		}
		w.Header().Set("X-Request-ID", id)
		r = r.WithContext(context.WithValue(r.Context(), requestIDKey, id))
		sw := &statusWriter{ResponseWriter: w, status: 200}
		start := time.Now()
		defer func() {
			if rec := recover(); rec != nil {
				log.Error("panic", "request_id", id, "panic", rec)
				Problem(sw, r, http.StatusInternalServerError, "Internal error", "")
			}
			// Never log bodies: they can contain health data.
			log.Info("http", "request_id", id, "method", r.Method, "path", r.URL.Path,
				"status", sw.status, "ms", time.Since(start).Milliseconds())
		}()
		next.ServeHTTP(sw, r)
	})
}

func Security(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h := w.Header()
		h.Set("X-Content-Type-Options", "nosniff")
		h.Set("Referrer-Policy", "no-referrer")
		h.Set("Cache-Control", "no-store")
		h.Set("Strict-Transport-Security", "max-age=63072000; includeSubDomains")
		next.ServeHTTP(w, r)
	})
}

func CORS(origins []string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if o := r.Header.Get("Origin"); o != "" && slices.Contains(origins, o) {
			w.Header().Set("Access-Control-Allow-Origin", o)
			w.Header().Set("Vary", "Origin")
			w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type, X-Request-ID")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusNoContent)
				return
			}
		}
		next.ServeHTTP(w, r)
	})
}
