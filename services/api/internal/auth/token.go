// Package auth issues and verifies access tokens, hashes secrets and derives
// patient login IDs.
package auth

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"strings"
	"time"
)

// Roles, from widest to narrowest access.
const (
	RolePlatformAdmin = "platform_admin"
	RoleClinicAdmin   = "clinic_admin"
	RoleClinician     = "clinician"
	RolePatient       = "patient"
)

// Principal is who is calling. ClinicID is empty only for platform admins.
type Principal struct {
	Subject   string `json:"sub"`           // user id or patient id
	Role      string `json:"role"`
	ClinicID  string `json:"clinic_id,omitempty"`
	PatientID string `json:"patient_id,omitempty"`
	IssuedAt  int64  `json:"iat"`
	ExpiresAt int64  `json:"exp"`
}

var (
	ErrBadToken = errors.New("invalid token")
	ErrExpired  = errors.New("token expired")
)

var b64 = base64.RawURLEncoding

const header = `{"alg":"HS256","typ":"JWT"}`

// Issue signs a compact JWT (HS256).
func Issue(secret []byte, p Principal, ttl time.Duration, now time.Time) (string, error) {
	p.IssuedAt = now.Unix()
	p.ExpiresAt = now.Add(ttl).Unix()
	body, err := json.Marshal(p)
	if err != nil {
		return "", err
	}
	signing := b64.EncodeToString([]byte(header)) + "." + b64.EncodeToString(body)
	return signing + "." + b64.EncodeToString(sign(secret, signing)), nil
}

// Verify checks the signature and expiry and returns the principal.
func Verify(secret []byte, token string, now time.Time) (Principal, error) {
	var p Principal
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return p, ErrBadToken
	}
	if h, err := b64.DecodeString(parts[0]); err != nil || string(h) != header {
		return p, ErrBadToken
	}
	sig, err := b64.DecodeString(parts[2])
	if err != nil || !hmac.Equal(sig, sign(secret, parts[0]+"."+parts[1])) {
		return p, ErrBadToken
	}
	body, err := b64.DecodeString(parts[1])
	if err != nil || json.Unmarshal(body, &p) != nil {
		return p, ErrBadToken
	}
	if now.Unix() >= p.ExpiresAt {
		return p, ErrExpired
	}
	switch p.Role {
	case RolePlatformAdmin:
	case RoleClinicAdmin, RoleClinician:
		if p.ClinicID == "" {
			return p, ErrBadToken
		}
	case RolePatient:
		if p.ClinicID == "" || p.PatientID == "" {
			return p, ErrBadToken
		}
	default:
		return p, ErrBadToken
	}
	return p, nil
}

func sign(secret []byte, s string) []byte {
	m := hmac.New(sha256.New, secret)
	m.Write([]byte(s))
	return m.Sum(nil)
}
