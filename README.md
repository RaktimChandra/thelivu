# Thelivu (தெளிவு)

**Cognitive remediation training for people living with schizophrenia.** Built for the SRM Medical College Hospital & Research Centre / SCARF randomised trial (with CINTEL, SRMIST), and designed to grow into a multi-clinic platform.

*Thelivu* means "clarity" in Tamil.

> Research software. Not a medical device. It does not diagnose or treat any condition and does not replace clinical care.

---

## What it does

- **Patients** train daily on short, adaptive games across the seven MATRICS cognitive domains: speed of processing, attention, working memory, verbal learning, visual learning, reasoning, and social cognition. The app is available in Tamil, Hindi and English. Instructions are shown by animated demos and voice, not walls of text.
- **Every game adapts.** A 3-down/1-up staircase keeps each person near 79% success, which is hard enough to learn from and easy enough to stay motivated.
- **Clinics** see every one of their own patients: daily sign-ins, session completion, time on task, accuracy, response time, errors and progression graphs. Clinicians can adjust difficulty at any time.
- **The platform admin** sees anonymised data across all clinics for quality, research and product improvement, within consent and DPDP Act 2023 rules.

## Status (week of 21 Nov 2026)

| Part | Path | Status |
| --- | --- | --- |
| Patient app (Godot 4.5, Android + web) | `apps/patient-app` | ✅ Skeleton complete: shell, session engine, SDK, offline store, telemetry, i18n, voice, safety |
| Domain 1 games: Quick Find, Same as Before, Sort It, plus Number Plate Check (swap-in) | `apps/patient-app/modules/d1_speed` | ✅ Playable, 10 levels each, 3 themes each, en/ta/hi, self-playing demos |
| Real human faces and hands pipeline | `tools/media`, `docs/research/THL-RES-002…` | ✅ Pipeline and policy ready; images await generation and clinical validation |
| Backend API (Go, PostgreSQL row-level security) | `services/api` | 🔨 In progress |
| Clinic portal (React + TypeScript) | `apps/clinic-portal` | 🔨 In progress |
| 3D architecture explorer | `viz/architecture-3d` | 🔨 In progress |
| Domains 2–7 | `apps/patient-app/modules/d2…d7` | ⏳ Planned. The library already shows them, so each domain plugs in without shell changes |

## Repository map

```
apps/
  patient-app/          Godot 4.5 client (GDScript)
    core/               App coordinator, session engine, services (store, i18n, telemetry, voice, sfx, modules)
    sdk/                Game Module SDK 1.0: GameModule, GameContext, Staircase, ThemePack, Media, Ui
    shell/              Screens (language, sign-in, home, library, game host, rest, progress, settings, safety)
    modules/<domain>/<game>/   Plug-in games: module.json + levels.json + themes/ + i18n/ + entry script
    locales/            en / ta / hi strings
    tests/              Headless test runner (unit, contract, i18n parity, end-to-end self-play)
docs/
  research/             THL-RES-001 Domain 1 dossier · THL-RES-002 real human media
  architecture/         System architecture, data model, security
  adr/                  Architecture decision records
  sdk/                  How to build a game module
  reports/              Weekly progress reports for the founder
tools/media/            Reproducible generation of real-human photo assets (open, commercial-safe models)
```

## Run it

**Patient app.** Install [Godot 4.5.1](https://godotengine.org/download), then:

```bash
godot --path apps/patient-app                                       # run the app
godot --headless --path apps/patient-app res://tests/runner.tscn    # run all tests
godot --headless --path apps/patient-app --export-release Web build/web/index.html
```

Deep links in the web build, for demos: `#screen=home&lang=ta`, `#game=d1_clerical_scan`, `#play=d1_speeded_sort&level=6`.

**Add a game.** See [`docs/sdk/MODULE_GUIDE.md`](docs/sdk/MODULE_GUIDE.md). In short, create a folder with `module.json`, `levels.json`, at least one theme and three language files, and an entry script that extends `GameModule`. The registry discovers it on launch; no shell code changes are needed.

## Principles

1. **Same mechanism, different elements.** A theme changes what a game looks like (a bus timetable, a kirana price list, a tablet schedule), never what the brain must do. Difficulty lives only in the level table.
2. **Errorless and respectful.** Gentle feedback, no red error colour, no timers that end a turn, practice that never counts, and a "not feeling well" button on every screen.
3. **Evidence first.** Every game has a research spec, a construct link and a metric plan. Every protocol deviation is written down and goes to the clinicians for a decision.
4. **Privacy by design.** Patients are identified by clinic-issued IDs, each clinic's data is isolated at the database level, and consent drives every use of data.

## Documentation

- [THL-RES-001 · Domain 1 research dossier: speed of processing](docs/research/THL-RES-001-domain1-speed-of-processing.md)
- [THL-RES-002 · Real human faces and hands](docs/research/THL-RES-002-real-human-media.md)
- [Architecture](docs/architecture/ARCHITECTURE.md) · [ADRs](docs/adr) · [Module guide](docs/sdk/MODULE_GUIDE.md) · [Weekly reports](docs/reports)

Proprietary. See `LICENSE` and `CREDITS.md`.
