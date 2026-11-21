## Module contract: every manifest is valid, every theme loads, every level row has the fields the game reads.
extends Node

const LEVEL_FIELDS := {
	"d1_clerical_scan": ["rows", "sim", "sorted", "goal_s", "font"],
	"d1_velocity_nback": ["n", "items", "show_s", "gap_s", "lure"],
	"d1_speeded_sort": ["bins", "rule", "switch", "goal_s"],
	"d1_plate_check": ["change", "exposure_s", "goal_s"],
	"d2_clock_test": ["ticks", "step_s", "p_jump", "window"],
	"d2_constant_driver": ["speed", "window_s", "gap_lo", "gap_hi", "lure", "signs", "fog", "night"],
	"d2_alnum_shift": ["mode", "pair", "hint", "congruent_p", "goal_s"],
	"d3_echo_eraser": ["k", "len_lo", "len_hi", "show_s"],
	"d3_vector_shift": ["grid", "moves", "arrow_s", "double", "no_backtrack"],
	"d3_number_letter_churn": ["length", "numbers", "show_s", "decoys", "guide"],
}


func test_registry_has_domain1(t) -> void:
	t.check(Modules.errors().is_empty(), "registry errors: %s" % str(Modules.errors()))
	var ids := Modules.all().map(func(m): return m.id)
	for id in LEVEL_FIELDS:
		t.check(id in ids, "module %s registered" % id)
	t.eq(Modules.by_domain("speed").size(), 3, "three official Domain 1 games")


func test_levels_and_themes(t) -> void:
	for m in Modules.all():
		var lv := Modules.levels(m.id)
		t.check(lv.size() >= 6, "%s has at least 6 levels" % m.id)
		for row in lv:
			for f in LEVEL_FIELDS.get(m.id, []):
				t.check(row.has(f), "%s level missing %s" % [m.id, f])
		for th in m.themes:
			var tp := Modules.theme_pack(m.id, th)
			t.check(tp.data.has("name"), "%s theme %s has a name" % [m.id, th])
		t.check(Modules.instantiate(m.id) != null, "%s instantiates" % m.id)


func test_clerical_document(t) -> void:
	var cs: Script = load(Modules.get_manifest("d1_clerical_scan").dir + "/clerical_scan.gd")
	var rng := RandomNumberGenerator.new()
	for sim in 4:
		for n in [4, 9, 14]:
			for kind in ["time", "price"]:
				rng.seed = sim * 100 + n
				var doc: Dictionary = cs.make_document(rng, 18, kind, n, sim, sim < 2)
				t.eq(doc.rows.size(), n, "rows sim=%d n=%d" % [sim, n])
				var target: Dictionary = doc.rows[doc.target_index]
				var matches: int = doc.rows.filter(func(r): return r.label == target.label and r.value == target.value).size()
				t.eq(matches, 1, "exactly one exact match")
				for r in doc.rows:
					t.check(cs.valid(kind, r.value), "valid %s value %d" % [kind, r.value])


func test_nback_sequence(t) -> void:
	var nb: Script = load(Modules.get_manifest("d1_velocity_nback").dir + "/velocity_nback.gd")
	var items: Array = Modules.theme_pack("d1_velocity_nback", "fruit").get_value("items", [])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for n in [1, 2]:
		var hist := []
		var matches := 0
		var total := 0
		for i in 3000:
			var pick: Dictionary = nb.next_item(rng, hist, n, 6, 0.3, items, 0.3)
			if hist.size() < n:
				t.check(not pick.match, "no match before n items")
			else:
				total += 1
				var is_rep: bool = pick.id == hist[hist.size() - n]
				t.check(is_rep == pick.match, "match flag is truthful")
				if pick.match:
					matches += 1
			hist.append(pick.id)
		var rate := float(matches) / total
		t.check(rate > 0.26 and rate < 0.34, "n=%d match rate %.3f near 0.30" % [n, rate])


func test_sort_items(t) -> void:
	var ss: Script = load(Modules.get_manifest("d1_speeded_sort").dir + "/speeded_sort.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var bins := [{"colour": 0, "kind": 2}, {"colour": 1, "kind": 0}, {"colour": 3, "kind": 1}, {"colour": 2, "kind": 3}]
	var conflict := 0
	for i in 2000:
		var rule: String = ["colour", "kind"][i % 2]
		var it: Dictionary = ss.make_item(rng, bins, "mixed", rule)
		var by_colour: int = bins.map(func(b): return b.colour).find(it.colour)
		var by_kind: int = bins.map(func(b): return b.kind).find(it.kind)
		t.eq(it.answer, by_colour if rule == "colour" else by_kind, "answer follows the active rule")
		t.eq(it.congruent, by_colour == by_kind, "congruent flag")
		if not it.congruent:
			conflict += 1
	t.check(conflict > 1350 and conflict < 1650, "about 75%% conflict trials (%d)" % conflict)


func test_plates(t) -> void:
	var pc: Script = load(Modules.get_manifest("d1_plate_check").dir + "/plate_check.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 500:
		var a: String = pc.random_plate(rng)
		t.eq(a.length(), 10, "plate length")
		for ch in ["obvious", "lookalike", "transpose"]:
			var b: String = pc.changed_plate(rng, a, ch)
			t.check(b != a and b.length() == 10, "%s change differs: %s %s" % [ch, a, b])


func test_domain2_official(t) -> void:
	t.eq(Modules.by_domain("attention").size(), 3, "three Domain 2 games")


func test_driver_events(t) -> void:
	var dr: Script = load(Modules.get_manifest("d2_constant_driver").dir + "/constant_driver.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var go := 0
	var lures := 0
	for i in 4000:
		var e: String = dr.pick_event(rng, true, 0.6)
		if e in ["brake", "breaker"]:
			go += 1
		elif e == "indicator":
			lures += 1
	t.check(go > 1850 and go < 2150, "half go events (%d)" % go)
	t.check(lures > 1050 and lures < 1350, "60%% of no-go are look-alike lights (%d)" % lures)
	rng.seed = 6
	for i in 500:
		t.check(dr.pick_event(rng, false, 0.0) in ["brake", "board"], "no signs or lures at level 1")


func test_alnum_stimuli(t) -> void:
	var al: Script = load(Modules.get_manifest("d2_alnum_shift").dir + "/alnum_shift.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var vowels := ["அ", "ஆ", "இ"]
	var cons := ["க்", "ச்", "ட்"]
	var incon := 0
	for i in 2000:
		var rule: String = ["number", "letter"][i % 2]
		var s: Dictionary = al.make_stimulus(rng, rule, true, 0.25, vowels, cons)
		var parts: PackedStringArray = s.text.split("  ")
		var digit := -1
		var letter := ""
		for part in parts:
			if part.is_valid_int():
				digit = int(part)
			else:
				letter = part
		var num_side := 0 if digit % 2 == 1 else 1
		var let_side := 0 if letter in vowels else 1
		t.eq(s.answer, num_side if rule == "number" else let_side, "answer follows the cued rule")
		t.eq(s.congruent, num_side == let_side, "congruency flag")
		if not s.congruent:
			incon += 1
	t.check(incon > 1350 and incon < 1650, "about 75%% incongruent (%d)" % incon)
	var r := ""
	var switches := 0
	for i in 1000:
		var n: String = al.pick_rule(rng, "random", i, r)
		if r != "" and n != r:
			switches += 1
		r = n
	t.check(switches > 420 and switches < 580, "random mode switches about half the time (%d)" % switches)
	t.eq(al.pick_rule(rng, "alt2", 0, ""), "number")
	t.eq(al.pick_rule(rng, "alt2", 2, "number"), "letter")


func test_domain3(t) -> void:
	t.eq(Modules.by_domain("working_memory").size(), 3, "three Domain 3 games")
	var ee: Script = load(Modules.get_manifest("d3_echo_eraser").dir + "/echo_eraser.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 300:
		var s: Array = ee.make_stream(rng, 9, 12)
		for j in range(1, s.size()):
			t.check(s[j] != s[j - 1], "no immediate repeats")
	var sc: Dictionary = ee.score_positions([3, 1, 4], [3, 4, 1])
	t.eq(sc.correct, 1, "strict serial scoring")
	var vs: Script = load(Modules.get_manifest("d3_vector_shift").dir + "/vector_shift.gd")
	for n in [3, 4, 5, 6]:
		for m in [2, 5, 8]:
			for dbl in [false, true]:
				var plan: Dictionary = vs.make_path(rng, n, m, dbl, true)
				var pos: Vector2i = plan.start
				var prev := ""
				for mv in plan.moves:
					pos += vs.DIRS[mv.dir] * int(mv.steps)
					t.check(pos.x >= 0 and pos.y >= 0 and pos.x < n and pos.y < n, "path stays on the grid")
					t.check(prev == "" or vs.DIRS[mv.dir] != -vs.DIRS[prev], "no immediate backtrack")
					prev = mv.dir
				t.eq(pos, plan.end, "end matches the replayed path")
				t.eq(plan.moves.size(), m, "move count")
	var ch: Script = load(Modules.get_manifest("d3_number_letter_churn").dir + "/number_letter_churn.gd")
	var alpha := ["அ", "ஆ", "இ", "ஈ", "உ", "ஊ"]
	for i in 300:
		var set_: Dictionary = ch.make_set(rng, 6, 3, alpha)
		t.eq(set_.shown.size(), 6, "length")
		var o: Array = set_.ordered
		t.check(o[0] is int and o[1] is int and o[2] is int and o[0] < o[1] and o[1] < o[2], "numbers ascending first")
		t.check(alpha.find(o[3]) < alpha.find(o[4]) and alpha.find(o[4]) < alpha.find(o[5]), "letters in script order")
		var d: Array = ch.make_decoys(rng, set_.shown, 2, alpha)
		for x in d:
			t.check(x not in set_.shown, "decoys were not shown")
