package auth

import (
	"crypto/rand"
	"fmt"
	"math/big"
	"strings"
	"time"
	"unicode"
)

// Unambiguous characters: no 0/O, 1/I/L, 5/S, 8/B.
const suffixAlphabet = "ACDEFGHJKMNPQRTUVWXY234679"

// NewThelivuID derives a memorable patient login ID from name and date of birth
// (startup requirement R1), e.g. "MEE-0412-K7":
//   - 3 letters of the first name (Latin letters only; non-Latin names use "THL")
//   - day and month of birth (the year is NOT included, to limit disclosure)
//   - 2 random characters, so IDs cannot be guessed from public facts
//
// The ID is a username, not a secret: sign-in also needs the PIN.
func NewThelivuID(name string, dob time.Time) (string, error) {
	prefix := letters(name, 3)
	if len(prefix) < 3 {
		prefix = "THL"
	}
	var b strings.Builder
	for i := 0; i < 2; i++ {
		n, err := rand.Int(rand.Reader, big.NewInt(int64(len(suffixAlphabet))))
		if err != nil {
			return "", err
		}
		b.WriteByte(suffixAlphabet[n.Int64()])
	}
	return fmt.Sprintf("%s-%02d%02d-%s", prefix, dob.Day(), int(dob.Month()), b.String()), nil
}

// NormalizeID makes typed IDs comparable (case, spaces, missing dashes).
func NormalizeID(s string) string {
	s = strings.ToUpper(strings.TrimSpace(s))
	s = strings.ReplaceAll(s, " ", "")
	if len(s) == 9 && !strings.Contains(s, "-") {
		s = s[:3] + "-" + s[3:7] + "-" + s[7:]
	}
	return s
}

func letters(name string, n int) string {
	var out []rune
	for _, r := range strings.ToUpper(name) {
		if r <= unicode.MaxASCII && unicode.IsLetter(r) {
			out = append(out, r)
			if len(out) == n {
				break
			}
		}
	}
	return string(out)
}
