package auth

import "golang.org/x/crypto/bcrypt"

// HashSecret hashes a password or PIN (bcrypt, cost 12).
func HashSecret(s string) (string, error) {
	b, err := bcrypt.GenerateFromPassword([]byte(s), 12)
	return string(b), err
}

// CheckSecret compares in constant time.
func CheckSecret(hash, s string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(s)) == nil
}
