extends Node


func _engine() -> SessionEngine:
	var e := SessionEngine.new()
	e.catalog = [
		{"id": "a1", "domain": "speed", "order": 1, "minutes": 5},
		{"id": "a2", "domain": "speed", "order": 2, "minutes": 5},
		{"id": "a3", "domain": "speed", "order": 3, "minutes": 5},
		{"id": "b1", "domain": "attention", "order": 1, "minutes": 5},
	]
	return e


func test_plan_picks_least_trained_domain(t) -> void:
	var e := _engine()
	e.week_minutes = {"speed": 40.0, "attention": 5.0}
	e.plan()
	t.eq(e.focus_domain, "attention")
	t.eq(e.queue.size(), 3, "block of 3 games")
	t.eq(e.queue[0], "b1")


func test_three_games_same_domain(t) -> void:
	var e := _engine()
	e.plan()
	t.eq(e.focus_domain, "speed", "ties broken by domain order")
	t.eq(Array(e.queue), ["a1", "a2", "a3"])


func test_hard_game_stays_easy_game_switches(t) -> void:
	var e := _engine()
	e.plan()
	var nxt := e.after_game("a1", 5.0, 0.55, false)   # hard
	t.eq(nxt, "a2")
	t.check(e.queue.has("a1"), "hard game stays in rotation")
	e.after_game("a2", 5.0, 0.92, false)               # mastered
	t.check(not e.queue.has("a2"), "mastered game leaves")
	t.check(e.queue.has("b1"), "replaced by weakest other domain")


func test_budget_and_completion(t) -> void:
	var e := _engine()
	e.budget_min = 12.0
	e.plan()
	e.after_game("a1", 5.0, 0.78, false)
	var nxt := e.after_game("a2", 5.0, 0.78, false)
	t.eq(nxt, "", "stops when the next game does not fit the time budget")
	t.check(not e.is_complete(), "2 games, 10 min is not complete by default rule")
	e.played.append({"module_id": "a3", "minutes": 5.0, "success": 0.8})
	t.check(e.is_complete(), "3 games completes the session")


func test_classify(t) -> void:
	var e := _engine()
	e.stats = {"x": {"success": 0.5}, "y": {"success": 0.78}, "z": {"success": 0.9}, "w": {"success": 0.76, "at_ceiling": true}}
	t.eq(e.classify("x"), "hard")
	t.eq(e.classify("y"), "on_target")
	t.eq(e.classify("z"), "mastered")
	t.eq(e.classify("w"), "mastered")
	t.eq(e.classify("none"), "unknown")
