package telemetry

import (
	"testing"
	"time"
)

func valid() Trial {
	return Trial{
		EventID: "3f1c2a4e-9b7d-4c1a-8e2f-1a2b3c4d5e6f", SessionID: "8a7b6c5d-4e3f-4a1b-9c8d-7e6f5a4b3c2d",
		ModuleID: "d1_clerical_scan", ModuleVersion: "1.0.0", ThemeID: "bus", Level: 3, Index: 0,
		Outcome: "correct", Correct: true, RTms: 2310, RecordedAt: "2026-11-21T04:30:00Z", SchemaVersion: "1.0",
	}
}

func TestValidate(t *testing.T) {
	now := time.Date(2026, 11, 21, 5, 0, 0, 0, time.UTC)
	ok := valid()
	if p := ok.Validate(now); p != "" {
		t.Fatalf("valid trial rejected: %s", p)
	}
	cases := map[string]func(*Trial){
		"bad uuid":     func(x *Trial) { x.EventID = "nope" },
		"bad module":   func(x *Trial) { x.ModuleID = "../etc" },
		"bad outcome":  func(x *Trial) { x.Outcome = "maybe" },
		"future":       func(x *Trial) { x.RecordedAt = "2026-11-22T05:00:00Z" },
		"level":        func(x *Trial) { x.Level = 0 },
		"schema major": func(x *Trial) { x.SchemaVersion = "2.0" },
		"big stimulus": func(x *Trial) { x.Stimulus = make([]byte, 5000) },
	}
	for name, mut := range cases {
		tr := valid()
		mut(&tr)
		if tr.Validate(now) == "" {
			t.Errorf("%s: should be rejected", name)
		}
	}
	miss := valid()
	miss.Outcome, miss.Correct, miss.RTms = "miss", false, -1
	if p := miss.Validate(now); p != "" {
		t.Errorf("miss with rt -1 rejected: %s", p)
	}
}
