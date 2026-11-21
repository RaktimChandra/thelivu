# ADR-0002 · Games as plug-in modules discovered from manifests

- Status: accepted · 2026-11-20
- Context:
  - There will be 21+ games across 7 domains, added over months.
  - Clinicians may swap a game, as with Number Plate Check versus N-Back.
  - The founder wants the "house" built once and the "furniture" added later.
- Decision:
  - Each game is a folder with `module.json`, which the `ModuleRegistry` discovers and validates at launch.
  - Games extend `GameModule` (SDK 1.0) and only touch the app through `GameContext` and the event bus.
  - Manifests declare `status: official | alternative`.
- Consequences:
  - Adding a game needs no shell changes.
  - A broken module is skipped and reported, and does not crash the app.
  - SDK major versions gate compatibility.
