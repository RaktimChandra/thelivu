## Local persistent state (offline-first). One JSON document, written atomically.
##
## Production note: on Android the encryption key moves to the Android Keystore
## through a plugin (ADR-0007). Here the file is encrypted with a per-install key
## so data is not readable as plain text on the device.
extends Node

const STATE_PATH := "user://thelivu_state.dat"
const KEY_PATH := "user://thelivu_key.dat"
const STATE_VERSION := 1

var _state: Dictionary = {}
var _key := ""


func _ready() -> void:
	_key = _load_or_create_key()
	_state = _read()
	if _state.is_empty() or int(_state.get("version", 0)) != STATE_VERSION:
		_state = _defaults()
		save()


func _defaults() -> Dictionary:
	return {
		"version": STATE_VERSION,
		"profile": {"patient_id": "", "display_name": "", "language": "", "clinic_id": "", "signed_in": false},
		"settings": {
			"text_scale": 1.0, "high_contrast": false, "sound": true, "voice": true,
			"session_budget_min": AppConfig.SESSION_BUDGET_MIN,
			"block_games": AppConfig.SESSION_BLOCK_GAMES,
			"rest_seconds": AppConfig.REST_SECONDS,
			"complete_min_minutes": AppConfig.COMPLETE_MIN_MINUTES,
			"complete_min_games": AppConfig.COMPLETE_MIN_GAMES,
		},
		"modules": {},       # module_id -> {level, theme, window:[0/1...], plays, last_result}
		"overrides": {},     # module_id -> clinician difficulty override (see apply_override)
		"days": {},          # "YYYY-MM-DD" -> {signed_in, minutes, games, complete}
		"domain_minutes": {},# "YYYY-Www" -> {domain: minutes}
		"session": {},       # in-progress session (resumable)
		"alerts": [],
	}


# ---------------------------------------------------------------- access
func get_value(path: String, default: Variant = null) -> Variant:
	var node: Variant = _state
	for part in path.split("."):
		if typeof(node) != TYPE_DICTIONARY or not (node as Dictionary).has(part):
			return default
		node = node[part]
	return node


func set_value(path: String, value: Variant, persist := true) -> void:
	var parts := path.split(".")
	var node: Dictionary = _state
	for i in parts.size() - 1:
		if not node.has(parts[i]) or typeof(node[parts[i]]) != TYPE_DICTIONARY:
			node[parts[i]] = {}
		node = node[parts[i]]
	node[parts[-1]] = value
	if persist:
		save()


func settings() -> Dictionary:
	return _state["settings"]


func module_state(module_id: String) -> Dictionary:
	var mods: Dictionary = _state["modules"]
	if not mods.has(module_id):
		mods[module_id] = {"level": -1, "theme": "", "window": [], "plays": 0, "last_result": {}}
	return mods[module_id]


## Clinician override (startup requirement R16). Keys: level, locked, floor, ceiling, goal_scale.
func override_for(module_id: String) -> Dictionary:
	return (_state["overrides"] as Dictionary).get(module_id, {})


func apply_override(module_id: String, override: Dictionary) -> void:
	(_state["overrides"] as Dictionary)[module_id] = override
	if override.has("level"):
		module_state(module_id)["level"] = int(override["level"])
	save()


# ---------------------------------------------------------------- daily tracking
static func today_key() -> String:
	return Time.get_date_string_from_system()


static func week_key() -> String:
	var d := Time.get_date_dict_from_system()
	var jan1 := Time.get_unix_time_from_datetime_dict({"year": d.year, "month": 1, "day": 1})
	var now := Time.get_unix_time_from_datetime_dict(d)
	var week := int((now - jan1) / 86400.0 / 7.0) + 1
	return "%d-W%02d" % [d.year, week]


func day() -> Dictionary:
	var days: Dictionary = _state["days"]
	var k := today_key()
	if not days.has(k):
		days[k] = {"signed_in": false, "minutes": 0.0, "games": 0, "complete": false}
	return days[k]


func add_domain_minutes(domain: String, minutes: float) -> void:
	var all: Dictionary = _state["domain_minutes"]
	var wk := week_key()
	if not all.has(wk):
		all[wk] = {}
	all[wk][domain] = float(all[wk].get(domain, 0.0)) + minutes
	save()


func week_domain_minutes() -> Dictionary:
	return (_state["domain_minutes"] as Dictionary).get(week_key(), {})


# ---------------------------------------------------------------- persistence
func save() -> void:
	var tmp := STATE_PATH + ".tmp"
	var f := FileAccess.open_encrypted_with_pass(tmp, FileAccess.WRITE, _key)
	if f == null:
		push_error("Store: cannot write state (%s)" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(_state))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(STATE_PATH))


func reset() -> void:
	_state = _defaults()
	save()


func _read() -> Dictionary:
	if not FileAccess.file_exists(STATE_PATH):
		return {}
	var f := FileAccess.open_encrypted_with_pass(STATE_PATH, FileAccess.READ, _key)
	if f == null:
		push_warning("Store: state unreadable, starting fresh")
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _load_or_create_key() -> String:
	if FileAccess.file_exists(KEY_PATH):
		var f := FileAccess.open(KEY_PATH, FileAccess.READ)
		if f:
			return f.get_as_text()
	var crypto := Crypto.new()
	var key := crypto.generate_random_bytes(32).hex_encode()
	var w := FileAccess.open(KEY_PATH, FileAccess.WRITE)
	if w:
		w.store_string(key)
	return key
