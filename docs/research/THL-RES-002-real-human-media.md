# THL-RES-002 · Real Human Faces and Hands in Thelivu

| Field | Value |
| --- | --- |
| Document | THL-RES-002, version 1.0 |
| Date | 21 November 2026 |
| Status | Draft for the founder and clinical team |
| Trigger | Founder request: use real human faces and hands (not drawn or animated ones) wherever a game needs a face or a hand |
| Affects | Domain 7 (social cognition) games, instruction demos in all domains, any theme that shows a person |

---

## 1. Decision summary

1. **Every face or hand a patient sees will be a photograph of a human, not a drawing.** The app now loads photos first (`.webp`, `.png`, `.jpg`) and falls back to drawings only while photos are not yet approved.
2. **Two sources, used in two phases.**
   - *Research trial (SRM MCH&RC / SCARF, non-commercial):* validated Indian emotion databases under a research licence: the IIM Indore **Indian Face Database** and the **AIIMS Facial Toolbox for Emotion Recognition (AFTER)**. These carry published validation, which is what a clinical trial needs.
   - *Commercial product (startup, clinics subscribe):* those research licences do **not** allow commercial use, so the product uses **synthetic photorealistic Indian faces and hands** made with open models that permit commercial use (FLUX.1-schnell and Qwen-Image-Edit, both Apache-2.0). This image set is then validated with the same rater method. Alternatively, the startup can fund its own photoshoot with actors who sign model releases.
3. **Nothing is shown until it is validated.** Every photo is listed in `assets/media/manifest.json` with its source, licence, consent basis and validation result. The app only displays assets marked `approved`.

---

## 2. Why real faces matter clinically

- Facial emotion recognition is impaired in schizophrenia and is linked to poor social functioning. Social-cognition training (for example SCIT and facial affect recognition training) uses photographs of real faces.
- Cartoon or emoji faces exaggerate and simplify expressions. Real faces carry subtle cues: eye-region changes, low-intensity expressions, mixed expressions. Those are the cues patients struggle with and need to practise.
- Culture affects how emotion is read. Most standard sets are Caucasian or East Asian, and Indian validation studies note that few Indian face databases exist. Faces should look like the people patients meet in Chennai.

---

## 3. Sources reviewed

| Source | What it is | Indian faces | Expressions | Licence / access | Fit |
| --- | --- | --- | --- | --- | --- |
| **Indian Face Database (IIM Indore, Tewari et al.)** | 1,302 validated images of 186 Indian adults (anger, disgust, fear, happy, sad, surprise, neutral), rated by 180 participants for emotion, clarity, genuineness, intensity and valence | Yes (north India) | 7 | By permission from the authors | **Best for the trial** |
| **AIIMS AFTER (Verma et al., IJPM 2023)** | 15 professional actors, 7 expressions at high and low intensity, 240 images; validated by 19 mental-health professionals | Yes | 7 × 2 intensities | Request from the authors | **Best for the trial** (intensity levels suit adaptive difficulty) |
| CFD-INDIA (Chicago Face Database extension) | 142 people recruited in Delhi | Yes | Neutral only | Non-commercial scientific research only | Neutral faces for identity and impression tasks (trial only) |
| Radboud Faces (RaFD) | Caucasian actors, 8 emotions; validated with an Indian sample | No | 8 | Non-commercial research | Fallback only |
| InFER, ISED, Mendeley Indian expressions | ML datasets of Indian expressions | Yes | Various | Mixed or unclear; spontaneous or unvalidated for clinical use | Not recommended for patient-facing stimuli |
| **FLUX.1-schnell** (Black Forest Labs) | Open text-to-image model, 12B parameters | Generated | Prompted | **Apache-2.0: personal, scientific and commercial use allowed** | **Product: neutral faces and hands** |
| **Qwen-Image-Edit-2509** (Alibaba Qwen) | Open image-editing model; changes the expression while keeping the same identity | Generated | Edited | **Apache-2.0** | **Product: expression sets per identity** |
| FLUX.1-dev, FLUX.1 Kontext-dev, StyleGAN | Strong models | — | — | Non-commercial licences | **Excluded** for the product |

---

## 4. Ethics, consent and law

- **Real people's photos** (databases or a photoshoot) are personal data under the DPDP Act 2023. Use them only under a written licence that permits this use, or with signed model releases covering commercial use, display to patients, and model training. Record the agreement ID in the manifest.
- **Synthetic faces** show no real person, so there is no consent burden and no re-identification risk. However:
  - Check every synthetic face against public-figure lookalikes; the reviewer rejects any image that resembles a known person.
  - Disclose in the app's "About" text and the clinic agreement that some faces are computer-generated.
  - Check for bias: the identity spec is balanced by sex, age (24–58), skin tone and region (Tamil, Malayali, Telugu, Kannadiga, North Indian). Accuracy is reported per identity group so that no group is systematically harder.
- **Patient safety:** no threatening, staring or close-up "watching" faces in non-social games (paranoia guardrail, THL-RES-001 §6). Anger and fear images appear only in Domain 7 games, at levels the clinician enables. No faces are used as distractors.
- **Model training:** a generated image is not training data about a patient. Patient responses to faces are, and they follow the platform's consent rules.

---

## 5. Validation protocol (required before `approved`)

Adapted from the AFTER and Indian Face Database procedures.

1. **Technical screen** (developer): no artefacts (hands with extra fingers, asymmetric eyes, warped teeth), consistent lighting and background, identity preserved across expressions.
2. **Expert rating:** at least 5 mental-health professionals from the SRM team label each image (forced choice among 7 emotions plus "unclear"), and rate intensity (1–9) and genuineness (1–9).
3. **Lay rating:** at least 20 healthy adult raters from Tamil Nadu, using the same forms.
4. **Acceptance:**
   - Intended emotion chosen by at least 70% of raters (happy and surprise: at least 80%).
   - High-intensity images rated higher in intensity than low-intensity images of the same identity.
   - Inter-rater agreement (Fleiss' κ) of at least 0.6 for the set.
5. **Record** the rater counts, percentage agreement and date in the manifest. Then the clinical lead runs `python tools/media/generate.py approve <ids> --by "<name>"`.
6. **Difficulty calibration:** per-image recognition accuracy from the raters becomes the image's difficulty value. Domain 7 games choose images by that value, the same way the other games use level tables.

Hands go through the technical screen and one clinical reviewer only.

---

## 6. How it is built (engineering)

| Piece | Where | What it does |
| --- | --- | --- |
| Photo-first loading | `sdk/media.gd`, `sdk/theme_pack.gd` | Any theme asset is loaded as a photo if one exists (`webp > png > jpg > svg`), so a theme upgrades to photographs by adding files, not code |
| Approval gate | `Media.approved(id)` + `assets/media/manifest.json` | Unapproved photos are never shown |
| Real-hand demos | `sdk/ui/demo_hand.gd` | Instruction demos use an approved photo of a pointing hand; the fingertip is anchored to the tap point |
| Generation pipeline | `tools/media/generate.py`, `tools/media/specs/*.json` | Reproducible: model, licence, prompt and seed are stored per image. Two backends: a local NVIDIA GPU (`--backend local`) or hosted Hugging Face inference (`--backend hf-api`, needs an HF token) |
| Expression sets | `faces_v1.json` | 12 identities × (neutral + 6 emotions × 2 intensities) = 156 images in the first set |

**First run (team laptop with an NVIDIA GPU):**

```bash
pip install -r tools/media/requirements.txt
python tools/media/generate.py hands --backend local
python tools/media/generate.py faces --backend local --identities f01,f02
```

---

## 7. Where faces and hands appear

| Domain | Game (planned) | Media |
| --- | --- | --- |
| All | Instruction demos | Real pointing hand |
| 1 Speed | Speeded Sorting, "hand" theme (founder's stick-to-hand idea) | Real hands holding coins and objects (optional theme) |
| 7 Social cognition | Emotion Match (which face shows the same feeling?) | Faces: 7 emotions × 2 intensities |
| 7 Social cognition | Emotion Intensity (which face is more…?) | Same identity, low vs high intensity |
| 7 Social cognition | What happens next? (face plus everyday scene) | Faces with simple context photos |
| 5 Visual learning | Face–name memory (who did you meet?) | Neutral faces |

---

## 8. Decisions requested

| ID | Decision | Recommendation |
| --- | --- | --- |
| DEC-06 | Request the Indian Face Database and AFTER for the trial (letter from the SRM PI) | Yes, this week |
| DEC-07 | Product face source: synthetic (Apache-2.0 models) or own photoshoot with releases | Synthetic now; photoshoot later if the budget allows |
| DEC-08 | Who signs off image approval | Clinical lead (psychiatry) plus one psychologist |
| DEC-09 | Disclose computer-generated faces to clinics and patients | Yes, in the About screen and clinic agreement |

---

## References

1. Verma R, Kalsi N, Shrivastava NP, Sheerha A. Development and Validation of the AIIMS Facial Toolbox for Emotion Recognition. *Indian J Psychol Med.* 2023;45. doi:10.1177/02537176221111578
2. Tewari S, Mehta S, et al. Indian Face Database (IIM Indore). OSF project f7zbv. https://osf.io/f7zbv
3. Lakshmi A, Wittenbrink B, Correll J, Ma DS. The India Face Set. *Front Psychol.* 2021;12:627678.
4. Ma DS, Correll J, Wittenbrink B. The Chicago Face Database. *Behav Res Methods.* 2015;47:1122–1135.
5. Mishra MV, Ray SB, Srinivasan N. Cross-cultural emotion recognition and evaluation of Radboud faces database with an Indian sample. *PLoS ONE.* 2018;13(10):e0203959.
6. Black Forest Labs. FLUX.1 [schnell] model card (Apache-2.0). https://huggingface.co/black-forest-labs/FLUX.1-schnell
7. Qwen Team. Qwen-Image-Edit-2509 model card (Apache-2.0). https://huggingface.co/Qwen/Qwen-Image-Edit-2509
8. Digital Personal Data Protection Act, 2023, and DPDP Rules, 2025 (Government of India).
