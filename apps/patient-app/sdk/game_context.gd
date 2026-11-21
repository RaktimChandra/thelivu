## Everything a game module may use. Modules never reach into the app directly,
## which is what keeps them swappable and testable (ADR-0004).
class_name GameContext
extends RefCounted

var manifest: Dictionary
var module_id := ""
var module_version := ""
var dir := ""
var levels: Array = []
var practice := false
var n_trials := 10
var theme: ThemePack
var staircase: Staircase
var rng := RandomNumberGenerator.new()
## Scales every soft time goal: from calibration (C-02) or a clinician (R16).
var goal_scale := 1.0


static func create(id: String, practice_mode: bool, theme_id := "", start_level := -1) -> GameContext:
	var c := GameContext.new()
	c.manifest = Modules.get_manifest(id)
	c.module_id = id
	c.module_version = str(c.manifest.version)
	c.dir = c.manifest.dir
	c.levels = Modules.levels(id)
	c.practice = practice_mode
	c.n_trials = int(c.manifest.trials.practice if practice_mode else c.manifest.trials.main)
	c.theme = Modules.theme_pack(id, theme_id)
	var lo := 1
	var hi := maxi(1, c.levels.size())
	var start := start_level
	if start < 1:
		start = lo if practice_mode else int(c.manifest.get("start_level", 2))
	c.staircase = Staircase.new(lo if practice_mode else start, lo, hi)
	if not practice_mode:
		var o := Store.override_for(id)
		c.staircase.apply_override(o)
		c.goal_scale = float(o.get("goal_scale", 1.0))
	c.rng.randomize()
	return c


func params(level: int) -> Dictionary:
	if levels.is_empty():
		return {}
	return levels[clampi(level - 1, 0, levels.size() - 1)]


## Module string: "<module_id>.<key>", falling back to a global key.
func t(key: String, vars: Dictionary = {}) -> String:
	var k := "%s.%s" % [module_id, key]
	return I18n.t(k, vars) if I18n.has(k) else I18n.t(key, vars)


func pick(arr: Array) -> Variant:
	return arr[rng.randi_range(0, arr.size() - 1)]


func shuffled(arr: Array) -> Array:
	var a := arr.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = a[i]
		a[i] = a[j]
		a[j] = tmp
	return a
