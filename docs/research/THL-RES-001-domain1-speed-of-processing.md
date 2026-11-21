# THL-RES-001 · Domain 1 Research Dossier: Speed of Processing

| Field | Value |
| --- | --- |
| Document ID | THL-RES-001 |
| Version | 1.0 (draft for clinical review) |
| Date | 21 November 2026 |
| Author | Raktim Chandra, platform engineer |
| Reviewers required | Principal Investigator; clinical psychologist (game content); statistician (metrics) |
| Applies to | Domain 1 games: Rapid Clerical Scan, Dynamic Velocity N-Back (+ Number Plate Check swap-in), Speeded Sorting |
| Status | Engineering evidence base. Not a clinical guideline. Every design decision marked **[DEC]** needs clinical sign-off before it ships to patients. |

---

## 0. Executive summary

1. **Processing speed is the single largest cognitive deficit in schizophrenia.** Across 37 studies (1,961 patients), digit-symbol coding tasks separated patients from controls with an effect of g = −1.57, larger than any other measure studied [3]; an extended analysis of 4,135 patients confirmed coding tasks as the largest effect (g = −1.50) [4].
2. **It can be trained, and gains transfer to other speed tasks.** In a randomised trial of 83 people with schizophrenia, processing-speed training produced gains on *untrained* speed tasks and on far-transfer tasks that required speed, while working-memory training did not transfer [7].
3. **Drill alone is not enough for real-life benefit.** Pooled cognitive remediation (CR) effects are reliable but modest (d = 0.29 on cognition, d = 0.22 on functioning, 130 trials, 8,851 participants) [5], and drill-and-practice computer training alone showed no effect on functional outcome in a recent meta-analysis [8]. Strategy coaching and bridging to daily life are what carry gains into life [6][9].
4. **People with schizophrenia learn best with high success and intrinsic motivation.** Errorless, high-success learning improves accuracy in this group [11]; personalisation, contextualisation and choice raise intrinsic motivation and learning [12][13].
5. **The founder's idea ("same mechanism, swap the elements") is supported by learning science, with conditions.** Varying surface features while keeping the task's mechanism constant (variability of practice) is linked to better generalisation [14][15], but variety does not help every kind of transfer [16]. So themes must be difficulty-matched and data-checked, not free decoration.
6. **Design consequences for Domain 1:** every game is built as *mechanism + theme pack*; difficulty adapts to hold 75–80% success; speed is pushed by a *soft* time goal, never a punishing timer; every game logs accuracy, response time, omissions and commissions; every game ends with a strategy tip linked to a daily-life task.

---

## 1. Schizophrenia in brief

### 1.1 What it is
Schizophrenia is a severe mental disorder involving psychosis (hallucinations, delusions, disorganised thinking), negative symptoms (reduced motivation, emotional expression and social drive) and cognitive impairment. WHO estimates it affects about 23 million people worldwide, 1 in 345 people, and more than two out of three people with psychosis worldwide do not receive specialist care [1].

### 1.2 India
The National Mental Health Survey (2015–16, 34,802 adults, 12 states) found a lifetime prevalence of schizophrenia-spectrum disorders of 1.41% and a current prevalence of 0.42%, with a 72% treatment gap that rose to 83.3% in urban non-metro areas [2]. A scalable, phone-based therapy addresses exactly this gap, provided it is clinically supervised.

### 1.3 Why cognition matters more than it seems
Antipsychotic medication controls psychosis but does little for cognition, and cognition predicts whether a person can work, study or live independently. Coding-task performance is a reliable indicator of illness severity and functional outcome [4]. The processing-speed impairment is also partly affected by antipsychotic dose [4], which means part of the slowing seen in patients is treatment-related and must be considered when interpreting progress.

---

## 2. The seven cognitive domains

The NIMH MATRICS initiative defined seven separable domains for treatment research: speed of processing, attention/vigilance, working memory, verbal learning, visual learning, reasoning and problem solving, and social cognition, measured by 10 tests in the MATRICS Consensus Cognitive Battery (MCCB) [10]. The study protocol structures the app around these seven domains.

**Speed of processing in the MCCB** is measured by three tests [10][17]:

| MCCB test | What the person does | What our games must *not* copy |
| --- | --- | --- |
| Trail Making Test A | Connect numbered circles in order, timed | Exact numbered-trail layout |
| BACS Symbol Coding | Write the digit matching each symbol, using a key, 90 s | Symbol–digit key format |
| Category Fluency (animals) | Name as many animals as possible in 60 s | Spoken category naming |

**[DEC-01]** Domain 1 games train the *skill* (fast visual scanning, matching and sorting) using different tasks, so that improvement on outcome tests reflects transfer, not practice on the test itself. The final outcome battery (the study uses the NIMHANS Neuropsychological Battery) must be shared with the developer so this separation can be checked (request PI-04).

---

## 3. Processing speed: the core deficit

- **Size.** Coding tasks show the largest impairment of any measure: g = −1.57 across 37 studies [3]; g = −1.50 in the extended analysis of 4,135 patients, followed by category fluency (g = −1.31) [4].
- **Stability.** The coding-task effect was reasonably consistent across samples and designs, and was not sensitive to medication status or symptoms in the original meta-analysis [3].
- **Centrality.** Processing-speed inefficiency is described as central to cognitive impairment in schizophrenia [4]; slowed processing constrains every other domain that has a time component.
- **Clinical link.** Processing speed is a reliable indicator of illness severity and functional outcome [4].

**What this means for design:** speed is the most impaired and the most "upstream" domain, so Domain 1 is a strong place to start. It is also the domain where a frustrating timer is most likely to cause distress. The games therefore push speed gently and adaptively.

---

## 4. Can processing speed be trained?

### 4.1 Domain-specific evidence
Cassetta, Tomfohr-Madsen and Goghari randomised 83 people with schizophrenia to computerised working-memory training, processing-speed training or no training [7]:
- Processing-speed training led to significant gains on **untrained** speed tasks and on far-transfer tasks that required speed.
- Working-memory training did **not** improve untrained working-memory tasks.
- Conclusion: there is some benefit of domain-specific training, specifically processing-speed training [7].

### 4.2 Broad cognitive remediation evidence
- Earlier meta-analysis: 26 RCTs, 1,151 patients, effect 0.41 on cognition and 0.36 on psychosocial functioning [18].
- Largest meta-analysis to date: 130 studies, 8,851 participants, d = 0.29 cognition, d = 0.22 functioning; effects were larger when programmes had a trained therapist, active development of strategies and structured bridging to daily life [5].
- Drill-and-practice-only computerised CR showed improvement in cognitive domains including processing speed but no effect on functional outcome [8].

### 4.3 What works: the four core features
An expert working group defined four core features of CR: a trained facilitator, cognitive exercise, procedures to develop cognitive strategies, and procedures to facilitate transfer to real-world functioning [6]. Strategy-based programmes such as CIRCuiTS were designed around metacognition and therapist support and showed good acceptability and adherence (85% adhered, median 28 sessions) [9].

**[DEC-02]** The app delivers the *cognitive exercise* feature fully and supports the other three: a strategy tip after every game, a bridging prompt linking the skill to daily life, and a facilitator mode in the clinician portal. The app is not marketed as a stand-alone cure.

---

## 5. How people with schizophrenia learn best

| Principle | Evidence | How Domain 1 applies it |
| --- | --- | --- |
| High success, few errors | Errorless learning improved job-task accuracy in schizophrenia; it minimises demands on explicit memory [11] | Staircase targets 75–80% success; practice rounds before counted play; errors shown neutrally |
| Intrinsic motivation | Amotivation is a hallmark of negative symptoms; personalisation, contextualisation and choice raised intrinsic motivation, learning and self-efficacy [12] | Patient chooses a theme; everyday Indian contexts (bus timetable, kirana, post office); visible personal progress |
| Value and competence | Perceived task value and competence predict persistence of learning [13] | Tell the patient *why* the game helps ("finding things faster on a bill or timetable"); show competence growth |
| Extrinsic rewards still help | Extrinsic reinforcers can raise attention and engagement in CR [19] | Points for consistency, milestones, gentle sound rewards; never leaderboards |
| Varied practice | Variability of practice improves schema building and transfer to novel situations [14]; stimulus variability improved generalisation after inhibition training [15] | Theme packs vary the surface while the mechanism stays constant |
| ...but variety is not magic | One study found stimulus variety did not improve low-road transfer of trained skills [16] | Themes are rotated, not mixed chaotically; effect of themes is measured (A/B analysis on de-identified data) |
| Far-transfer claims are weak for N-back | WM training (often n-back) shows near/intermediate gains but no convincing far transfer [20] | Velocity N-Back is positioned as a speed-under-load task, not an "IQ booster"; Number Plate Check is kept as a swap-in |

---

## 6. The founder's principle: same mechanism, different elements

**The idea.** Keep the cognitive mechanism of a game fixed (for example, "find the target among distractors as fast as possible") but change the elements (bus times → medicine strips → train boards; a stick → a hand; letters → coins).

**Why it is sound.**
1. *Generalisation:* varied surface features with a constant deep structure support transfer to new situations [14][15].
2. *Motivation:* choosing a theme is personalisation and choice, which raise intrinsic motivation in schizophrenia [12].
3. *Contextualisation:* themes drawn from real daily tasks are the bridge to daily life the evidence asks for [5][6].
4. *Engagement over 12 weeks:* novelty slows boredom without changing what is trained.

**The guardrails (engineering rules).**

| Rule | Why | Implementation |
| --- | --- | --- |
| A theme may change *what things look like*, never *what the brain must do* | Keeps the training dose and the metric comparable | Theme packs contain assets and labels only; all timing, counts and difficulty live in the mechanism's level table |
| Every theme is difficulty-matched | A harder-looking theme would silently raise difficulty | Each theme declares its visual complexity; the analytics pipeline checks per-theme accuracy and response time; outlier themes are flagged |
| Themes are rotated by rule, not randomly every item | Too much variety can hurt early learning [16] | Theme fixed within a game round; changes between sessions or on the patient's choice |
| Culture and language fit | Contextualisation only works if the context is familiar | Indian, Chennai-first contexts; text-free assets wherever possible |
| No unsettling imagery | Paranoid ideation is common | No watching eyes, no surveillance, no threat imagery, no sudden loud sounds |

---

## 7. Attention-catching without harm

The founder asked for games that catch attention. In schizophrenia this must be balanced against distractibility, sensory overload and paranoia.

**Do:** clear focal motion (the target moves or pulses), crisp feedback within 100 ms of a tap, short celebratory animation on success, warm colour accents for the one thing that matters, a progress ring, short rounds (60–120 s), and a visible end.

**Don't:** flash more than three times per second (WCAG 2.3.1 photosensitivity threshold), use red for errors, use countdown alarms, shake the screen, crowd the screen with decoration, or make anything move in the periphery that is not part of the task.

**[DEC-03]** "Juice" is applied to *feedback and transitions*, never to distractors, unless a level explicitly trains distractor resistance and the clinician approves it.

---

## 8. Domain 1 game specifications

Common to all three games: a demo video with native voice-over before first play; a practice round that never counts; a 3-down/1-up staircase holding success near 79%; a soft time goal derived from calibration; per-trial logging of stimulus, response, response time, correctness, omission and commission; pause/resume; and a closing strategy tip.

### 8.1 Game 1 · Rapid Clerical Scan (official, protocol D1-G1)
| Aspect | Specification |
| --- | --- |
| Clinical goal | Visual scanning speed and efficient search among look-alikes |
| Mechanism | A target is shown (for example, "the 7:45 bus"); the patient finds and taps the matching line in a realistic document |
| Construct link | Visual search / scanning efficiency (relates to the scanning demand in Trail Making A without copying it) |
| Difficulty levers | Number of rows (4 → 14); similarity of distractors (none → digit swaps → AM/PM → transpositions); sort order (sorted → unsorted); type size down to a readable floor; soft time goal (12 s → 6 s) |
| Themes (A/B elements) | MTC bus timetable · kirana price list · medicine strip schedule · railway departure board · electricity bill · ration card list |
| Metrics | Time to find, wrong taps (commissions), "I can't find it" (omissions), success vs goal |
| Protocol deviation | Protocol: strict 15 s limit. Proposed: soft time goal that never ends the round (D-04) |
| Strategy tip | "Look at one line at a time, top to bottom, and check the first number first." |
| Daily-life bridge | Finding a bus time, a price, or a medicine dose quickly |

### 8.2 Game 2 · Dynamic Velocity N-Back (official, protocol D1-G2)
| Aspect | Specification |
| --- | --- |
| Clinical goal | Speed of perceptual comparison under a short memory load |
| Mechanism | Items stream from left to right. The patient taps "Match" when the current item is the same as the one shown *n* steps before (n = 1 or 2) |
| Construct link | Processing speed under load. Note: also loads working memory (n-back) |
| Difficulty levers | Stream speed (adapts per the protocol); n (1 → 2); number of distinct items (3 → 8); look-alike items; match rate fixed at about 30% |
| Themes | Shapes · fruit on a market cart · vehicles on a road · fish in a stream · festival lamps |
| Metrics | Hits, misses (omissions), false alarms (commissions), response time, sensitivity d′ |
| Protocol deviation | Protocol: speed increases "with every correct answer". Proposed: speed follows the 3-down/1-up staircase so success stays near 79% instead of rising until failure |
| Clinical flag | N-back paradigms are used in outcome batteries and show weak far transfer [20]. Built as specified; **Number Plate Check** (same/different on Tamil Nadu number plates) is provided as a swap-in module so the clinicians can choose (D-05) |
| Strategy tip | "Say the item softly in your head. When the next one comes, compare it with what you said." |
| Daily-life bridge | Keeping track of a moving sequence: bus numbers, a queue token |

### 8.3 Game 3 · Speeded Sorting (official, protocol D1-G3)
| Aspect | Specification |
| --- | --- |
| Clinical goal | Speed of categorisation and response selection, as in clerical and industrial work |
| Mechanism | Items appear one at a time; the patient taps the right bin as fast as possible. A sign says the sorting rule |
| Construct link | Perceptual-motor speed and simple decision speed; later levels add cued rule switching |
| Difficulty levers | Bins 2 → 4; feature (colour → shape → both in conflict); rule switch every 4 items → unpredictable; soft time goal 2.8 s → 1.6 s |
| Themes | Post-office letters (pincode colour) · coins by value · vegetables into baskets · medicine strips into a pill box · files by colour |
| Metrics | Accuracy, response time, wrong-bin errors, switch cost |
| Protocol deviation | Protocol describes physical sorting; implemented on screen (D-04) |
| Strategy tip | "Check the sign first, then look only at that one feature." |
| Daily-life bridge | Sorting mail, coins, groceries or medicines |

### 8.4 Swap-in · Number Plate Check (alternative to Game 2)
Same/different judgement on two Tamil Nadu number plates; changes go from obvious to single look-alike characters (8/0, B/D), transpositions and district codes, then brief exposure. Pure perceptual comparison speed without an n-back memory load.

---

## 9. What good outcomes look like

| Level | Indicator | Realistic expectation |
| --- | --- | --- |
| Engagement | Sessions completed / planned | Remote CR has higher drop-out than in-person; target ≥ 70% adherence with reminders and facilitator calls |
| In-app learning | Level progression; response time falls while accuracy holds near 79% | Expected in most patients within 2–4 weeks |
| Near transfer | Improvement on untrained speed tasks (MCCB speed composite or the study battery) | Supported by domain-specific evidence [7] |
| Broad cognition | Composite cognitive score | Small effect, d ≈ 0.3 [5] |
| Functioning | Daily-life functioning measures | Small effect, d ≈ 0.2, and only with strategy and bridging components [5][8] |

The app must never claim more than this to patients, clinics or regulators.

---

## 10. Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Timer-induced stress or distress | Soft goals, no countdown alarms, stop at any time, "I'm not feeling well" on every screen |
| Training the outcome test | Different tasks for the same skill (DEC-01); swap-in for N-back (D-05) |
| Theme changes difficulty | Difficulty matching and per-theme analytics (section 6) |
| Low motivation (negative symptoms) | Choice, context, visible competence, facilitator contact [12][13] |
| Phone timing differences | Touch-latency calibration per device; response times compared within patient |
| Photosensitivity | No flashing above 3 Hz; automated check in CI |
| Over-claiming benefit | Section 9 limits; marketing review by the PI |

---

## 11. Decisions requested from the clinical team

| ID | Question | Recommendation |
| --- | --- | --- |
| DEC-01 | Confirm outcome tests so games avoid copying them | Share the NIMHANS battery subtests used |
| DEC-02 | App supports, not replaces, facilitator sessions | Yes |
| DEC-03 | Attention-catching effects limited to feedback | Yes |
| D-04 | Soft time goals instead of hard limits | Yes |
| D-05 | Velocity N-Back or Number Plate Check in the trial | Number Plate Check for the trial; N-Back available for clinics |
| DEC-04 | Theme list per game | Approve the six themes per game above |
| DEC-05 | Calibration pilot size and rules | 20–30 patients; start one level below the highest level passed |

---

## References

1. World Health Organization. *Schizophrenia* fact sheet. https://www.who.int/news-room/fact-sheets/detail/schizophrenia
2. Hegde PR, Nirisha LP, et al. Schizophrenia spectrum disorders in India: a population-based study. *Indian J Psychiatry* 2023;65(12):1223–1229. https://www.pubmed.gov/38298877/
3. Dickinson D, Ramsey ME, Gold JM. Overlooking the obvious: a meta-analytic comparison of digit symbol coding tasks and other cognitive measures in schizophrenia. *Arch Gen Psychiatry* 2007;64:532–542. Summarised in: https://www.cambridge.org/core/product/5A721AA30FA33CC840F4D8D7144B4F6F/core-reader
4. Knowles EEM, David AS, Reichenberg A. Processing speed deficits in schizophrenia: reexamining the evidence. *Am J Psychiatry* 2010;167:828–835. https://psychiatryonline.org/doi/10.1176/appi.ajp.2010.09070937
5. Vita A, Barlati S, Ceraso A, et al. Effectiveness, core elements, and moderators of response of cognitive remediation for schizophrenia. *JAMA Psychiatry* 2021;78(8):848–858. https://doi.org/10.1001/jamapsychiatry.2021.0620
6. Bowie CR, Bell MD, Fiszdon JM, et al. Cognitive remediation for schizophrenia: an expert working group white paper on core techniques. *Schizophr Res* 2020;215:49–53.
7. Cassetta BD, Tomfohr-Madsen LM, Goghari VM. A randomized controlled trial of working memory and processing speed training in schizophrenia. *Psychol Med* 2019;49:2009–2019. https://www.pubmed.gov/30278853/
8. Kambeitz-Ilankovic L, Betz LT, Dominke C, et al. Multi-outcome meta-analysis (MOMA) of cognitive remediation in schizophrenia: revisiting the relevance of human coaching and elucidating interplay between multiple outcomes. *Neurosci Biobehav Rev* 2019. Reports a prior meta-analysis in which drill-and-practice computerised CR showed no effect on functional outcome. https://pmc.ncbi.nlm.nih.gov/articles/PMC8942567
9. Reeder C, Huddy V, Cella M, et al. A new generation computerised metacognitive cognitive remediation programme for schizophrenia (CIRCuiTS): a randomised controlled trial. *Psychol Med* 2017;47(15):2720–2730. https://pmc.ncbi.nlm.nih.gov/articles/PMC5647677
10. Nuechterlein KH, Green MF, Kern RS, et al. The MATRICS Consensus Cognitive Battery, part 1: test selection, reliability, and validity. *Am J Psychiatry* 2008;165:203–213. https://ajp.psychiatryonline.org/doi/10.1176/appi.ajp.2007.07010042
11. Kern RS, Liberman RP, Kopelowicz A, Mintz J, Green MF. Applications of errorless learning for improving work performance in persons with schizophrenia. *Am J Psychiatry* 2002;159:1921–1926. https://ajp.psychiatryonline.org/doi/10.1176/appi.ajp.159.11.1921
12. Choi J, Medalia A. Intrinsic motivation and learning in a schizophrenia spectrum sample. *Schizophr Res* 2010;118:12–19. https://pmc.ncbi.nlm.nih.gov/articles/PMC2856796
13. Choi J, Fiszdon JM, Medalia A. Expectancy-value theory in persistence of learning effects in schizophrenia. *Schizophr Bull* 2010;36:957–965. https://pmc.ncbi.nlm.nih.gov/articles/PMC2930342
14. Variability of practice (encyclopedia entry, Springer). https://link.springer.com/referenceworkentry/10.1007%2F978-1-4419-1428-6_415
15. Stimulus variability improves generalization following response inhibition training. *Psychol Res* 2023. https://link.springer.com/content/pdf/10.1007/s00426-023-01913-w.pdf
16. Variety in cognitive training and low-road transfer (three experiments incl. n-back). https://escholarship.org/uc/item/91z5j3hm
17. MCCB speed of processing composite (Symbol Coding, Category Fluency, Trail Making A). https://clinicaltrials.gov/study/NCT03079024
18. McGurk SR, Twamley EW, Sitzer DI, McHugo GJ, Mueser KT. A meta-analysis of cognitive remediation in schizophrenia. *Am J Psychiatry* 2007;164:1791–1802. https://pmc.ncbi.nlm.nih.gov/articles/PMC3634703
19. Silverstein SM. Bridging the gap between extrinsic and intrinsic motivation in the cognitive remediation of schizophrenia. *Schizophr Bull* 2010;36:949–956. https://pmc.ncbi.nlm.nih.gov/articles/PMC2930334
20. Melby-Lervåg M, Redick TS, Hulme C. Working memory training does not improve performance on measures of intelligence or other measures of "far transfer". *Perspect Psychol Sci* 2016;11:512–534. https://pmc.ncbi.nlm.nih.gov/articles/PMC4968033
21. Raje A, Rozatkar AR, Mehta UM, et al. Designing smartphone-based cognitive assessments for schizophrenia: perspectives from a multisite study (Boston, Bhopal, Bangalore). *Schizophr Res Cogn* 2025. https://doaj.org/article/67d88b4706104d0a8971d96d976848d6
