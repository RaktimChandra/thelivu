# Building a game module (SDK 1.0)

A module is a folder. The app finds it on launch, validates it and makes it playable: in the library, inside daily sessions, in progress screens and in telemetry. You never edit the shell.

```
apps/patient-app/modules/<domain_pack>/<game>/
  module.json        manifest (identity, domain, trials, themes)
  levels.json        difficulty table: level 1 is index 0
  <entry>.gd         script that extends GameModule
  icon.svg           library icon
  themes/<id>/theme.json (+ assets/*.svg|webp|png)   look and words only
  i18n/en.json ta.json hi.json                        name, goal, tip, voice[], game strings
```

## 1. Manifest (`module.json`)

| Field | Required | Meaning |
| --- | --- | --- |
| `id` | yes | Globally unique, `d<domain#>_<name>` |
| `domain` | yes | One of `speed, attention, working_memory, verbal, visual, reasoning, social` |
| `status` | no | `official` (default, used in sessions) or `alternative` (library only, for clinician choice) |
| `order` | no | Position within the domain |
| `version`, `sdk` | yes | Module semver; SDK major version must match the app (`1.x`) |
| `entry`, `levels` | yes | File names |
| `themes`, `default_theme` | yes | Theme folder ids |
| `trials` | yes | `{"practice": n, "main": n}` |
| `start_level`, `minutes` | no | First level for new patients; typical block length (used by the session planner) |
| `protocol_ref`, `mechanism`, `metrics`, `stair_success`, `research` | recommended | Traceability to the research dossier |

## 2. The game script

```gdscript
extends GameModule

func _build() -> void:
    # create persistent UI inside `stage` (a VBoxContainer); set_prompt("...")
    pass

func _present_trial(level: int, p: Dictionary, index: int) -> void:
    # p = this level's row from levels.json
    # show the stimulus, then:
    mark_onset()                        # response time starts now
    demo_tap(correct_button)            # only acts in self-playing demo mode
    # ... later, on the patient's answer:
    # complete_trial({"correct": ok, "kind": "correct|wrong|omission|hit|miss|false_alarm|correct_reject",
    #                 "stair": ok and rt_ms() <= goal_ms(p), "stimulus": {...}, "response": {...}})
```

The base class handles the trial loop, the staircase, pause (with paused time excluded from response times), feedback, sounds, the level-up banner, telemetry, the result summary and the self-playing instruction demo.

Helpers:
- `after(sec, fn)`: pause-aware timers that cancel automatically when the trial moves on.
- `goal_ms(p)`: the soft time goal, after calibration or clinician scaling.
- `ctx.theme.texture(name)`: loads a theme image; a photo wins over an SVG.
- `ctx.t(key)`: module strings.
- `ctx.rng`: the random generator.
- `ctx.pick()`, `ctx.shuffled()`: random choice and shuffle.

## 3. Rules every module must follow

1. **Themes never change difficulty.** Timings, counts and similarity live only in `levels.json`.
2. **Every trial is logged** through `complete_trial`; never write telemetry yourself.
3. **No red for errors, no flashing above 3 Hz, no countdown alarms, no surprise sounds.**
4. **Patient-facing instructions** are a demo plus voice; on screen, keep to one short goal line.
5. **Put pure logic in `static func`s** (for example, stimulus generation) so it can be unit-tested.
6. **Add the module to `tests/test_modules.gd`** (the level fields it reads) and give it a logic test.

## 4. Check it

```bash
godot --headless --path apps/patient-app res://tests/runner.tscn
```

The runner:
- compiles every script;
- validates every manifest, theme and level row;
- checks that all three languages have your keys;
- lets every module **play itself for 12 trials** to prove the loop never stalls.
