## Runtime localisation. A language is a folder of JSON files, so adding one
## needs no code change (feature Q-02): res://locales/<code>.json plus each
## module's i18n/<code>.json, namespaced by module id.
extends Node

const SUPPORTED := ["en", "ta", "hi"]
const NATIVE_NAMES := {"en": "English", "ta": "தமிழ்", "hi": "हिन्दी"}
const TTS_LOCALES := {"en": "en_IN", "ta": "ta_IN", "hi": "hi_IN"}

var lang := "en"
var _tables := {}  # lang -> {key: text}


func _ready() -> void:
	for code in SUPPORTED:
		_tables[code] = _read_json("res://locales/%s.json" % code)


## Merge a module's strings under "<module_id>.<key>".
func register_module_strings(module_id: String, base_dir: String) -> void:
	for code in SUPPORTED:
		var table: Dictionary = _read_json("%s/i18n/%s.json" % [base_dir, code])
		for k in table:
			_tables[code]["%s.%s" % [module_id, k]] = table[k]


func set_language(code: String) -> void:
	if code not in SUPPORTED:
		code = "en"
	lang = code
	TranslationServer.set_locale(code)
	Store.set_value("profile.language", code)
	Bus.language_changed.emit(code)


## Look up a key; {name} placeholders are replaced from vars.
func t(key: String, vars: Dictionary = {}) -> String:
	var s: String = _tables.get(lang, {}).get(key, _tables["en"].get(key, key))
	for k in vars:
		s = s.replace("{%s}" % k, str(vars[k]))
	return s


func has(key: String) -> bool:
	return _tables.get(lang, {}).has(key) or _tables["en"].has(key)


## A list value (JSON array) for the current language, e.g. letter sets.
func list(key: String) -> Array:
	var v: Variant = _tables.get(lang, {}).get(key, _tables["en"].get(key, []))
	return v if typeof(v) == TYPE_ARRAY else []


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
