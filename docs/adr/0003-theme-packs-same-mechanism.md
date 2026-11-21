# ADR-0003 · Theme packs: same mechanism, different elements

- Status: accepted · 2026-11-20
- Context: The founder's principle is to swap elements (A for B, a stick for a hand) while keeping the mechanism. The research supports this through variability of practice and personal choice, provided difficulty does not drift.
- Decision: Themes may contain only labels, colours and images. All difficulty parameters live in `levels.json`. Each theme declares `complexity`, and analytics compares per-theme accuracy and RT so that outlier themes get flagged.
- Consequences: Engagement gets new looks at zero clinical risk, and metrics stay comparable across themes.
