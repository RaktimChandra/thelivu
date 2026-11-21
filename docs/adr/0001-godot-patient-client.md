# ADR-0001 · Godot 4 for the patient app

- Status: accepted · 2026-11-14
- Context: The patient app must run smoothly on low-cost Android phones, render game-like motion at 60 fps, work offline, ship Tamil and Hindi text, and also run on the web for demos.
- Decision: Godot 4.5 with GDScript and the GL Compatibility renderer (OpenGL ES 3 / WebGL 2). Portrait 720×1280 canvas scaled to every screen.
- Consequences:
  - One codebase for Android and web.
  - Real-time animation and timing are first-class.
  - The UI is drawn by the engine, so platform accessibility services (TalkBack) need extra work; the plan is AccessKit support in Godot 4.5+, plus large targets and voice by default.
