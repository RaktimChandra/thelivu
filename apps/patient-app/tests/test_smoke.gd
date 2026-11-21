## End-to-end: boot the shell, visit every screen, and let every module play
## itself through a full block (fast-forwarded) to prove the loop never stalls.
extends Node

signal done
var _async := {"test_every_module_completes": true, "test_shell_screens": true}


func is_async(name: String) -> bool:
	return _async.has(name)


func test_shell_screens(t) -> void:
	var main: Control = load("res://shell/boot.tscn").instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	for s in ["language", "signin", "home", "library", "progress", "settings", "safety", "session_done"]:
		App.go(s)
		await get_tree().process_frame
		await get_tree().process_frame
		t.check(main.get("_current") != null and main._current.screen_name == s, "screen %s shown" % s)
	main.queue_free()
	await get_tree().process_frame
	done.emit()


func test_every_module_completes(t) -> void:
	Engine.time_scale = 20.0
	for m in Modules.all():
		var g := Modules.instantiate(m.id)
		var holder := Control.new()
		holder.size = Vector2(720, 1100)
		get_tree().root.add_child(holder)
		holder.add_child(g)
		var ctx := GameContext.create(m.id, false)
		g.setup(ctx)
		g.play_demo(holder)        # self-play
		g.ctx.n_trials = 12
		var finished := false
		var start := Time.get_ticks_msec()
		while Time.get_ticks_msec() - start < 20000:
			await get_tree().process_frame
			if g._index >= 12:
				finished = true
				break
		t.check(finished, "%s self-played 12 trials (got %d)" % [m.id, g._index])
		var r := g.result()
		t.check(r.trials >= 12, "%s result counted trials" % m.id)
		holder.queue_free()
	Engine.time_scale = 1.0
	done.emit()
