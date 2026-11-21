// Single source of truth for the 3D model. Status: built | progress | planned.
// Paths point into the repository so a viewer can find the real code.
export const STATUS = {
  built: { color: 0x1e7568, label: "Built and tested" },
  progress: { color: 0xd49a33, label: "In progress" },
  planned: { color: 0x8aa0b8, label: "Planned slot (ready to plug in)" },
};

export const CORE = [
  ["App coordinator", "built", "apps/patient-app/core/app.gd", "Fonts, navigation, sign-in, daily tracking (R2), session lifecycle, points."],
  ["Session engine", "built", "apps/patient-app/core/session_engine.gd", "45-minute day: 3 games from the weakest domain; hard games stay, mastered games switch domain (R18)."],
  ["Encrypted store", "built", "apps/patient-app/core/services/store.gd", "Offline state on the phone, encrypted with a per-install key; atomic saves."],
  ["Telemetry queue", "built", "apps/patient-app/core/services/telemetry.gd", "Every trial becomes an event (accuracy, response time, omissions, commissions: R4, R15); queued offline, synced in batches."],
  ["Languages", "built", "apps/patient-app/core/services/i18n.gd", "Tamil, Hindi, English at runtime; each game brings its own strings."],
  ["Voice", "built", "apps/patient-app/core/services/voice.gd", "Recorded clips first, phone text-to-speech as fallback (R14)."],
  ["Module registry", "built", "apps/patient-app/core/services/module_registry.gd", "Discovers games from module.json, validates them, skips broken ones safely. New games need no shell changes."],
];

export const SDK = [
  ["GameModule base", "built", "apps/patient-app/sdk/game_module.gd", "Trial loop, pause-aware timing, feedback, level-up, results and the self-playing demo for every game."],
  ["Staircase 3-down/1-up", "built", "apps/patient-app/sdk/staircase.gd", "Keeps each person near 79% success (R7, R9); clinician floor, ceiling and lock (R16)."],
  ["Theme packs", "built", "apps/patient-app/sdk/theme_pack.gd", "Same mechanism, different elements: themes change looks and words, never difficulty."],
  ["Real-photo media", "built", "apps/patient-app/sdk/media.gd", "Photos first (real hands and faces), shown only when clinically approved."],
  ["Game context", "built", "apps/patient-app/sdk/game_context.gd", "Gives a game its level table, theme, random source and clinician overrides."],
  ["Design system", "built", "apps/patient-app/sdk/ui/ui.gd", "Calm colours, large touch targets, Tamil and Hindi fonts, no red for errors."],
];

export const SCREENS = ["Language", "Sign-in", "Home", "Activities", "Game host", "Rest", "Progress", "Settings", "Safety", "Session done"];

export const DOMAINS = [
  { id: "speed", name: "1 · Speed of processing", games: [
    ["Quick Find", "built", "d1_speed/clerical_scan", "Find the matching line in a bus timetable, price list or tablet schedule."],
    ["Same as Before (n-back)", "built", "d1_speed/velocity_nback", "Items stream past; tap when one matches the one before."],
    ["Sort It", "built", "d1_speed/speeded_sort", "Sort by colour or type; later the rule switches."],
  ], alt: ["Number Plate Check (alt.)", "built", "d1_speed/plate_check", "Swap-in for the n-back: are two number plates the same?"] },
  { id: "attention", name: "2 · Attention", games: [
    ["The Clock Test", "built", "d2_attention/clock_test", "Tap when the hand jumps two marks (vigilance)."],
    ["The Constant Driver", "built", "d2_attention/constant_driver", "Brake for brake lights, ignore indicators and boards."],
    ["Alphanumeric Shift", "built", "d2_attention/alnum_shift", "Odd/even or vowel/consonant, depending on the card's position."],
  ] },
  { id: "wm", name: "3 · Working memory", games: [
    ["The Echo Eraser", "built", "d3_working_memory/echo_eraser", "Keep only the last few items of a stream."],
    ["Vector Shifting", "built", "d3_working_memory/vector_shift", "Track a hidden dot as it moves on a grid."],
    ["Number–Letter Churn", "built", "d3_working_memory/number_letter_churn", "Numbers in order, then letters in your script's order."],
  ] },
  { id: "verbal", name: "4 · Verbal learning", games: [["Slot 1", "planned"], ["Slot 2", "planned"], ["Slot 3", "planned"]] },
  { id: "visual", name: "5 · Visual learning", games: [["Slot 1", "planned"], ["Slot 2", "planned"], ["Slot 3", "planned"]] },
  { id: "reason", name: "6 · Reasoning", games: [["Slot 1", "planned"], ["Slot 2", "planned"], ["Slot 3", "planned"]] },
  { id: "social", name: "7 · Social cognition (real faces)", games: [["Slot 1", "planned"], ["Slot 2", "planned"], ["Slot 3", "planned"]] },
];

export const CLOUD = [
  ["Go API", "built", "services/api", "Sign-in, idempotent telemetry ingestion, sessions, alerts, roster, progress, overrides. Every request runs in a clinic-scoped transaction."],
  ["PostgreSQL + row-level security", "built", "services/api/migrations/0001_init.up.sql", "Clinic A can never read clinic B's rows, enforced by the database itself (integration-tested)."],
  ["Audit log", "built", "services/api/migrations/0001_init.up.sql", "Every clinician read and change of patient data is recorded."],
  ["Consent records", "built", "services/api/migrations/0001_init.up.sql", "Care, research, product improvement and model training consent, per DPDP Act 2023."],
  ["Research warehouse", "planned", "docs/architecture/ARCHITECTURE.md", "De-identified data for the startup's analysis and model training, only where consent allows."],
];

export const PORTAL = [
  ["Patient roster", "built", "apps/clinic-portal/src/pages/Patients.tsx", "Who signed in today, trials today, last 7 days, alerts (R2, R3, R10)."],
  ["Progress graphs", "built", "apps/clinic-portal/src/pages/PatientDetail.tsx", "Training time, accuracy and response time, errors and level progression per game (R11, R13, R15)."],
  ["Difficulty control", "built", "apps/clinic-portal/src/pages/PatientDetail.tsx", "Set, hold or bound a game's level with an audited reason (R16)."],
  ["Safety alerts", "built", "apps/clinic-portal/src/pages/Alerts.tsx", "Every 'I'm not feeling well' press, for the care team."],
];

export const TOUR = [
  { target: "overview", title: "Thelivu at a glance", text: "Three buildings: the patient app (left), the cloud (right) and the clinic portal (front). Light flowing between them is data: trials go up, clinician settings come back." },
  { target: "floor:core", title: "Ground floor · Core services", text: "Works fully offline on the phone: session planning, encrypted storage, the trial log, three languages and voice. The module registry finds every game automatically." },
  { target: "floor:sdk", title: "First floor · Game SDK", text: "The engine every game shares: timing, the 79% staircase, pause, feedback, demos that play themselves, and themes that swap the look but never the difficulty." },
  { target: "domain:speed", title: "Domain 1 · Speed of processing", text: "Furnished: Quick Find, Same as Before and Sort It, with Number Plate Check as a swap-in. Ten levels and three looks each, in Tamil, Hindi and English." },
  { target: "domain:attention", title: "Domains 2 and 3 · Attention and working memory", text: "Furnished: The Clock Test, The Constant Driver and Alphanumeric Shift; The Echo Eraser, Vector Shifting and Number–Letter Churn. Each was added as a folder dropped into its room, with no changes to the house." },
  { target: "domain:social", title: "Empty rooms, ready", text: "Verbal learning, visual learning, reasoning and social cognition already have their rooms and slots. Social cognition will use validated real human faces." },
  { target: "roof", title: "Roof · Screens", text: "Language, sign-in, home, activities, game host, rest, progress, settings and the always-available safety screen." },
  { target: "building:cloud", title: "The cloud", text: "Go API and PostgreSQL. Row-level security walls each clinic off inside the database itself; every clinician action is audited; consent is recorded per purpose." },
  { target: "building:portal", title: "Clinic portal", text: "Clinicians see their own patients: daily sign-ins, training time, accuracy, response time, errors and progress graphs, and can adjust difficulty with a reason." },
];
