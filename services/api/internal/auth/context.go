package auth

import (
	"context"
	"net/http"
	"slices"
	"strings"
	"time"
)

type ctxKey struct{}

func WithPrincipal(ctx context.Context, p Principal) context.Context {
	return context.WithValue(ctx, ctxKey{}, p)
}

func From(ctx context.Context) (Principal, bool) {
	p, ok := ctx.Value(ctxKey{}).(Principal)
	return p, ok
}

// Require authenticates the bearer token and checks the role.
func Require(secret []byte, roles []string, onFail func(http.ResponseWriter, *http.Request, int, string), next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		h := r.Header.Get("Authorization")
		tok, ok := strings.CutPrefix(h, "Bearer ")
		if !ok {
			onFail(w, r, http.StatusUnauthorized, "missing bearer token")
			return
		}
		p, err := Verify(secret, tok, time.Now())
		if err != nil {
			onFail(w, r, http.StatusUnauthorized, err.Error())
			return
		}
		if !slices.Contains(roles, p.Role) {
			onFail(w, r, http.StatusForbidden, "role not allowed")
			return
		}
		next(w, r.WithContext(WithPrincipal(r.Context(), p)))
	}
}
