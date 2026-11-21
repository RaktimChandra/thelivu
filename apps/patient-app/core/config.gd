## Platform-wide constants. Clinic-level values arrive from the server and
## override the defaults kept in Store (see Store.settings()).
class_name AppConfig
extends RefCounted

const APP_VERSION := "0.2.0"
const SDK_VERSION := "1.0"
const SCHEMA_VERSION := "1.0"

## Staircase (3-down / 1-up): converges near 79.4% success (Levitt, 1971).
const STAIR_DOWN_RUN := 3
## Target success band for monitoring (protocol: 75–80%).
const TARGET_BAND_LOW := 0.75
const TARGET_BAND_HIGH := 0.80
## Rolling window for success-rate monitoring, in items.
const SUCCESS_WINDOW := 20

## Session defaults (startup requirement R18; clinic may override).
const SESSION_BUDGET_MIN := 45
const SESSION_BLOCK_GAMES := 3
const REST_SECONDS := 120
const COMPLETE_MIN_MINUTES := 30
const COMPLETE_MIN_GAMES := 3

## Responses faster than this are anticipations, not reactions (metrics dictionary).
const MIN_VALID_RT_MS := 150

const DOMAINS := ["speed", "attention", "working_memory", "verbal", "visual", "reasoning", "social"]
