## Game module registry (the "furniture" plug-in point).
##
## A game module is a self-contained folder under res://modules/<domain_pack>/<module>/
## with a module.json manifest that follows contracts/schemas/game-module.schema.json.
## Dropping a valid folder in is all it takes to add a game: the registry finds it,
## validates it, registers its strings, and the session engine can schedule it.
extends Node

const ROOT := "res://modules"
const REQUIRED := ["id", "domain", "version", "sdk", "entry", "levels", "themes", "default_theme", "trials"]

var _modules := {}       # id -> manifest (+ "dir")
var _errors: Array[String] = []


func _ready() -> void:
	scan()


func scan() -> void:
	_modules.clear()
	_errors.clear()
	for pack in _dirs(ROOT):
		for mod in _dirs("%s/%s" % [ROOT, pack]):
			var dir := "%s/%s/%s" % [ROOT, pack, mod]
			var manifest_path := dir + "/module.json"
			if not FileAccess.file_exists(manifest_path):
				continue
			var m: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
			var problem := _validate(m, dir)
			if problem != "":
				_errors.append("%s: %s" % [dir, problem])
				push_warning("ModuleRegistry: skipped %s (%s)" % [dir, problem])
				continue
			m["dir"] = dir
			_modules[m.id] = m
			I18n.register_module_strings(m.id, dir)


func errors() -> Array[String]:
	return _errors


func all() -> Array:
	var list := _modules.values()
	list.sort_custom(func(a, b): return SessionEngine.lex_less([a.domain_index, a.order], [b.domain_index, b.order]))
	return list


func get_manifest(id: String) -> Dictionary:
	return _modules.get(id, {})


func has(id: String) -> bool:
	return _modules.has(id)


func by_domain(domain: String, include_alternatives := false) -> Array:
	return all().filter(func(m): return m.domain == domain and (include_alternatives or m.get("status", "official") == "official"))


func domains_with_modules() -> Array:
	var out := []
	for d in AppConfig.DOMAINS:
		if not by_domain(d).is_empty():
			out.append(d)
	return out


## Level table for a module: Array of Dictionaries, index 0 = level 1.
func levels(id: String) -> Array:
	var m := get_manifest(id)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s" % [m.dir, m.levels]))
	return parsed.get("levels", []) if typeof(parsed) == TYPE_DICTIONARY else []


func theme_pack(id: String, theme_id: String) -> ThemePack:
	var m := get_manifest(id)
	if theme_id not in m.themes:
		theme_id = m.default_theme
	return ThemePack.load_from("%s/themes/%s" % [m.dir, theme_id], theme_id)


## Create a playable instance of a module. Returns null if the entry is invalid.
func instantiate(id: String) -> GameModule:
	var m := get_manifest(id)
	if m.is_empty():
		return null
	var script: Script = load("%s/%s" % [m.dir, m.entry])
	if script == null:
		push_error("ModuleRegistry: cannot load entry for %s" % id)
		return null
	var node: Object = script.new()
	if not node is GameModule:
		push_error("ModuleRegistry: %s entry does not extend GameModule" % id)
		return null
	return node


func _validate(m: Variant, dir: String) -> String:
	if typeof(m) != TYPE_DICTIONARY:
		return "module.json is not an object"
	for k in REQUIRED:
		if not m.has(k):
			return "missing field '%s'" % k
	if m.domain not in AppConfig.DOMAINS:
		return "unknown domain '%s'" % m.domain
	if str(m.sdk).split(".")[0] != AppConfig.SDK_VERSION.split(".")[0]:
		return "SDK %s not supported (app SDK %s)" % [m.sdk, AppConfig.SDK_VERSION]
	if not ResourceLoader.exists("%s/%s" % [dir, m.entry]):
		return "entry script not found"
	if not FileAccess.file_exists("%s/%s" % [dir, m.levels]):
		return "level table not found"
	if m.default_theme not in m.themes:
		return "default theme not in themes"
	m["domain_index"] = AppConfig.DOMAINS.find(m.domain)
	m["order"] = int(m.get("order", 99))
	return ""


static func _dirs(path: String) -> PackedStringArray:
	var d := DirAccess.open(path)
	if d == null:
		return PackedStringArray()
	var out := d.get_directories()
	out.sort()
	return out
