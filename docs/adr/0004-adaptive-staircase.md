# ADR-0004 · 3-down/1-up staircase for all difficulty

- Status: accepted · 2026-11-20
- Context: The startup's requirement R7 asks for a 75–80% success rate, and calibration must not start too hard (R9).
- Decision: Use a transformed staircase: one level harder after 3 consecutive successes, one level easier after 1 failure. It converges near 79.4% (Levitt 1971; verified by simulation in `tests/test_staircase.gd`). A "success" is defined per module, for example correct *and* within the soft time goal. New patients start at level 1–2. Clinician overrides can set a floor, a ceiling, a fixed level or a time-goal scale.
- Consequences: One rule across all games. Protocol text such as "speed increases with every correct answer" is implemented through the staircase, and this deviation is documented for clinical sign-off.
