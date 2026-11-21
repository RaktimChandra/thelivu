## Daily session planner (startup requirement R18; features D-01 to D-04, E-18).
##
## Rules, in order:
##  1. A session has a time budget (default 45 min) and starts with a block of
##     games (default 3) from one focus domain.
##  2. Focus domain = the domain with the lowest training minutes this week
##     (ties broken by lowest average success), among domains that have games.
##  3. After each game: if the patient is below the target band (75%), the game
##     stays in today's rotation; if they are above it (>80%) or at the top
##     level with success >= 75%, it is "mastered" and swapped for a game from
##     the weakest other domain that has games; otherwise it stays.
##  4. The session is complete when the clinic's rule is met (minutes or games).
##
## Pure logic: no scene tree, no I/O. Inputs are plain data, so it is unit-tested
## in tests/test_session_engine.gd and mirrored by the server's planner.
class_name SessionEngine
extends RefCounted

var budget_min := 45.0
var block_games := 3
var complete_min_minutes := 30.0
var complete_min_games := 3

## catalog: Array of manifests {id, domain, order, minutes}
var catalog: Array = []
## stats: module_id -> {success: float (0..1, -1 = unknown), at_ceiling: bool}
var stats: Dictionary = {}
## week_minutes: domain -> minutes trained this week
var week_minutes: Dictionary = {}

var queue: Array[String] = []
var played: Array = []   # [{module_id, minutes, success}]
var focus_domain := ""


func configure(settings: Dictionary) -> SessionEngine:
	budget_min = float(settings.get("session_budget_min", budget_min))
	block_games = int(settings.get("block_games", block_games))
	complete_min_minutes = float(settings.get("complete_min_minutes", complete_min_minutes))
	complete_min_games = int(settings.get("complete_min_games", complete_min_games))
	return self


func domains_available() -> Array:
	var out := []
	for m in catalog:
		if m.domain not in out:
			out.append(m.domain)
	return out


func modules_in(domain: String) -> Array:
	var list := catalog.filter(func(m): return m.domain == domain)
	list.sort_custom(func(a, b): return int(a.get("order", 99)) < int(b.get("order", 99)))
	return list.map(func(m): return m.id)


func domain_success(domain: String) -> float:
	var vals := []
	for id in modules_in(domain):
		var s := float(stats.get(id, {}).get("success", -1.0))
		if s >= 0.0:
			vals.append(s)
	if vals.is_empty():
		return 0.0
	var total := 0.0
	for v in vals:
		total += v
	return total / vals.size()


## Weakest domain = fewest minutes this week, then lowest success, then catalog order.
func weakest_domain(exclude: Array = []) -> String:
	var best := ""
	var best_key := []
	for d in domains_available():
		if d in exclude:
			continue
		var key := [float(week_minutes.get(d, 0.0)), domain_success(d), AppConfig.DOMAINS.find(d)]
		if best == "" or SessionEngine.lex_less(key, best_key):
			best = d
			best_key = key
	return best


static func lex_less(a: Array, b: Array) -> bool:
	for i in mini(a.size(), b.size()):
		if a[i] < b[i]:
			return true
		if a[i] > b[i]:
			return false
	return a.size() < b.size()


func plan() -> Array[String]:
	queue.clear()
	played.clear()
	focus_domain = weakest_domain()
	if focus_domain == "":
		return queue
	var mods := modules_in(focus_domain)
	for i in block_games:
		queue.append(mods[i % mods.size()])
	return queue


func minutes_played() -> float:
	var total := 0.0
	for p in played:
		total += float(p.minutes)
	return total


func is_complete() -> bool:
	return minutes_played() >= complete_min_minutes or played.size() >= complete_min_games


func budget_left() -> float:
	return budget_min - minutes_played()


func classify(module_id: String) -> String:
	var s: Dictionary = stats.get(module_id, {})
	var success := float(s.get("success", -1.0))
	if success < 0.0:
		return "unknown"
	if success < AppConfig.TARGET_BAND_LOW:
		return "hard"
	if success > AppConfig.TARGET_BAND_HIGH or (bool(s.get("at_ceiling", false)) and success >= AppConfig.TARGET_BAND_LOW):
		return "mastered"
	return "on_target"


## Record a finished game and return the next module id ("" = session over).
func after_game(module_id: String, minutes: float, success: float, at_ceiling: bool) -> String:
	played.append({"module_id": module_id, "minutes": minutes, "success": success})
	stats[module_id] = {"success": success, "at_ceiling": at_ceiling}
	var dom := _domain_of(module_id)
	week_minutes[dom] = float(week_minutes.get(dom, 0.0)) + minutes
	if not queue.is_empty() and queue[0] == module_id:
		queue.remove_at(0)
	var state := classify(module_id)
	if state == "mastered":
		var other := weakest_domain([dom])
		if other != "":
			var candidates := modules_in(other)
			queue.append(candidates[0])
	else:
		queue.append(module_id)   # hard or on target: keep practising it today
	var next_minutes := _minutes_of(queue[0]) if not queue.is_empty() else 0.0
	if queue.is_empty() or budget_left() < next_minutes:
		return ""
	return queue[0]


func _domain_of(id: String) -> String:
	for m in catalog:
		if m.id == id:
			return m.domain
	return ""


func _minutes_of(id: String) -> float:
	for m in catalog:
		if m.id == id:
			return float(m.get("minutes", 6))
	return 6.0
