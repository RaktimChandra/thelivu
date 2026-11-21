## Transformed up–down staircase (Levitt, 1971): 3 successes in a row → one
## level harder; 1 failure → one level easier. Converges near 79.4% success,
## inside the protocol's 75–80% target band (ADR-0005).
##
## Clinician overrides (startup requirement R16): floor, ceiling and lock.
class_name Staircase
extends RefCounted

var level: int
var min_level: int
var max_level: int
var locked := false
var _run := 0
var trace: Array = []  # [{level, ok}]


func _init(start: int, lo: int, hi: int) -> void:
	min_level = lo
	max_level = hi
	level = clampi(start, lo, hi)


func apply_override(o: Dictionary) -> void:
	if o.has("floor"):
		min_level = clampi(int(o.floor), 1, max_level)
	if o.has("ceiling"):
		max_level = clampi(int(o.ceiling), min_level, max_level)
	if o.has("level"):
		level = int(o.level)
	locked = bool(o.get("locked", false))
	level = clampi(level, min_level, max_level)


## Returns "up", "down" or "same".
func record(ok: bool) -> String:
	trace.append({"level": level, "ok": ok})
	if locked:
		return "same"
	if ok:
		_run += 1
		if _run >= AppConfig.STAIR_DOWN_RUN:
			_run = 0
			if level < max_level:
				level += 1
				return "up"
		return "same"
	_run = 0
	if level > min_level:
		level -= 1
		return "down"
	return "same"


func at_ceiling() -> bool:
	return level >= max_level
