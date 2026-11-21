# ADR-0005 · Real photographs for faces and hands, approval-gated

- Status: accepted · 2026-11-21
- Context: The founder requires real human faces and hands, not drawn ones. Validated Indian face databases are licensed for non-commercial research only; the product is commercial.
- Decision:
  - Photo-first asset loading (`webp > png > jpg > svg`).
  - Every photo is registered in `assets/media/manifest.json` and is shown only when `approved`.
  - Trial phase: licensed validated databases (IIM Indore IFD, AIIMS AFTER).
  - Product: synthetic photorealistic faces and hands from Apache-2.0 models (FLUX.1-schnell, Qwen-Image-Edit-2509), validated by raters.
- Consequences: Licences stay clean, there is no consent burden for synthetic faces, a validation workload falls on the clinical team, and generated faces must be disclosed. See THL-RES-002.
