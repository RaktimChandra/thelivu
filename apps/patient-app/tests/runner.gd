## Headless test runner. Usage:
##   godot --headless --path apps/patient-app res://tests/runner.tscn
## Exit code 0 = all passed. Runs: script compile check, unit tests, module
## contract checks and an end-to-end smoke test of every module (self-play).
extends Node

const SUITES := [
	"res://tests/test_compile.gd",
	"res://tests/test_staircase.gd",
	"res://tests/test_session_engine.gd",
	"res://tests/test_modules.gd",
	"res://tests/test_i18n.gd",
	"res://tests/test_smoke.gd",
]

var passed := 0
var failed := 0
var _current := ""


func _ready() -> void:
	# Watchdog: a hung test must fail the run, never block CI.
	get_tree().create_timer(240.0, true, false, true).timeout.connect(func():
		printerr("WATCHDOG: tests did not finish in 240 s")
		get_tree().quit(2))
	Store.reset()
	await get_tree().process_frame
	for path in SUITES:
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			_fail("cannot load suite %s" % path)
			continue
		var suite: Node = script.new()
		add_child(suite)
		for m in suite.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			_current = "%s::%s" % [path.get_file().get_basename(), name]
			var before := failed
			suite.call(name, self)
			if suite.has_method("is_async") and suite.is_async(name):
				await suite.done
			if failed == before:
				passed += 1
				print("  ok   ", _current)
		suite.queue_free()
	print("\n%d passed, %d failed" % [passed, failed])
	Store.reset()
	get_tree().quit(0 if failed == 0 else 1)


func check(cond: bool, msg: String) -> void:
	if not cond:
		_fail(msg)


func eq(a: Variant, b: Variant, msg := "") -> void:
	if a != b:
		_fail("%s expected %s got %s" % [msg, str(b), str(a)])


func _fail(msg: String) -> void:
	failed += 1
	printerr("  FAIL ", _current, " — ", msg)
