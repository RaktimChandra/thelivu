## Every script in the project must load and compile.
extends Node


func test_all_scripts_compile(t) -> void:
	var paths := []
	_walk("res://", paths)
	t.check(paths.size() > 20, "found %d scripts" % paths.size())
	for p in paths:
		var s: Script = load(p)
		t.check(s != null and s.can_instantiate(), "script fails to compile: %s" % p)


func _walk(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if sub.begins_with("."):
			continue
		_walk(dir.path_join(sub), out)
