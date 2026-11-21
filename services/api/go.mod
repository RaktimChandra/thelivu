module github.com/RaktimChandra/thelivu/services/api

go 1.24

require (
	github.com/jackc/pgx/v5 v5.7.2
	golang.org/x/crypto v0.31.0
)

require (
	github.com/jackc/pgpassfile v1.0.0 // indirect
	github.com/jackc/pgservicefile v0.0.0-20240606120523-5a60cdf6a761 // indirect
	github.com/jackc/puddle/v2 v2.2.2 // indirect
	golang.org/x/sync v0.12.0 // indirect
	golang.org/x/text v0.21.0 // indirect
)

// golang.org/x modules are fetched from their official GitHub mirrors so the
// build works on networks that only allow GitHub (our CI and dev sandboxes).
replace (
	golang.org/x/crypto => github.com/golang/crypto v0.31.0
	golang.org/x/net => github.com/golang/net v0.33.0
	golang.org/x/sync => github.com/golang/sync v0.12.0
	golang.org/x/sys => github.com/golang/sys v0.28.0
	golang.org/x/term => github.com/golang/term v0.27.0
	golang.org/x/text => github.com/golang/text v0.23.0
	gopkg.in/check.v1 => github.com/go-check/check v0.0.0-20201130134442-10cb98267c6c
	gopkg.in/yaml.v3 => github.com/go-yaml/yaml/v3 v3.0.1
)
