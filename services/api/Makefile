# Thelivu API
TEST_DB ?= postgres://postgres@127.0.0.1:55432/postgres

.PHONY: build test test-integration vet run
build:
	go build ./...
vet:
	go vet ./...
test:
	go test ./...
test-integration:   ## needs a throwaway PostgreSQL 15+ superuser URL
	THELIVU_TEST_DATABASE_URL=$(TEST_DB) go test ./internal/server -run Integration -v
run:
	go run ./cmd/api
