package auth

import (
	"regexp"
	"strings"
	"testing"
	"time"
)

var secret = []byte("test-secret-test-secret-test-secret!")

func TestTokenRoundTrip(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	tok, err := Issue(secret, Principal{Subject: "u1", Role: RoleClinician, ClinicID: "c1"}, time.Hour, now)
	if err != nil {
		t.Fatal(err)
	}
	p, err := Verify(secret, tok, now.Add(30*time.Minute))
	if err != nil || p.ClinicID != "c1" || p.Role != RoleClinician {
		t.Fatalf("verify: %v %+v", err, p)
	}
	if _, err := Verify(secret, tok, now.Add(2*time.Hour)); err != ErrExpired {
		t.Fatalf("want expired, got %v", err)
	}
	if _, err := Verify([]byte("another-secret-another-secret-12345"), tok, now); err != ErrBadToken {
		t.Fatalf("want bad signature, got %v", err)
	}
	parts := strings.Split(tok, ".")
	forged := parts[0] + "." + b64.EncodeToString([]byte(`{"sub":"x","role":"platform_admin","exp":9999999999}`)) + "." + parts[2]
	if _, err := Verify(secret, forged, now); err != ErrBadToken {
		t.Fatalf("forged payload accepted: %v", err)
	}
}

func TestClinicRolesNeedClinic(t *testing.T) {
	now := time.Now()
	tok, _ := Issue(secret, Principal{Subject: "u1", Role: RoleClinician}, time.Hour, now)
	if _, err := Verify(secret, tok, now); err != ErrBadToken {
		t.Fatal("clinician token without clinic must be rejected")
	}
}

func TestThelivuID(t *testing.T) {
	dob := time.Date(1990, 12, 4, 0, 0, 0, 0, time.UTC)
	re := regexp.MustCompile(`^[A-Z]{3}-\d{4}-[` + suffixAlphabet + `]{2}$`)
	for _, tc := range []struct{ name, prefix string }{
		{"Meena Kumari", "MEE"}, {"  r. suresh", "RSU"}, {"மீனா", "THL"}, {"Al", "THL"},
	} {
		id, err := NewThelivuID(tc.name, dob)
		if err != nil || !re.MatchString(id) || !strings.HasPrefix(id, tc.prefix+"-0412-") {
			t.Errorf("%q -> %q (%v)", tc.name, id, err)
		}
	}
	if NormalizeID(" mee0412k7 ") != "MEE-0412-K7" {
		t.Error("normalize")
	}
}

func TestSecretHash(t *testing.T) {
	h, err := HashSecret("2468")
	if err != nil || !CheckSecret(h, "2468") || CheckSecret(h, "2469") {
		t.Fatal("hash/check")
	}
}
