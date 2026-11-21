extends Node


func test_three_down_one_up(t) -> void:
	var s := Staircase.new(3, 1, 10)
	t.eq(s.record(true), "same")
	t.eq(s.record(true), "same")
	t.eq(s.record(true), "up")
	t.eq(s.level, 4)
	t.eq(s.record(false), "down")
	t.eq(s.level, 3)


func test_bounds(t) -> void:
	var s := Staircase.new(1, 1, 2)
	t.eq(s.record(false), "same", "cannot go below floor")
	for i in 6:
		s.record(true)
	t.eq(s.level, 2, "cannot exceed ceiling")
	t.check(s.at_ceiling(), "at ceiling")


func test_override_lock(t) -> void:
	var s := Staircase.new(5, 1, 10)
	s.apply_override({"level": 7, "locked": true})
	t.eq(s.level, 7)
	for i in 3:
		s.record(true)
	t.eq(s.level, 7, "locked level does not move")


func test_converges_near_79_percent(t) -> void:
	# Simulated patient whose p(correct) falls 8 points per level.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var s := Staircase.new(1, 1, 20)
	var ok := 0
	var n := 4000
	for i in n:
		var p := clampf(1.05 - 0.08 * s.level, 0.05, 0.99)
		var r := rng.randf() < p
		if r:
			ok += 1
		s.record(r)
	var rate := float(ok) / n
	t.check(rate > 0.74 and rate < 0.84, "success rate %.3f should be near 0.79" % rate)
