## Module contract: every manifest is valid, every theme loads, every level row has the fields the game reads.
extends Node

const LEVEL_FIELDS := {
	"d1_clerical_scan": ["rows", "sim", "sorted", "goal_s", "font"],
	"d1_velocity_nback": ["n", "items", "show_s", "gap_s", "lure"],
	"d1_speeded_sort": ["bins", "rule", "switch", "goal_s"],
	"d1_plate_check": ["change", "exposure_s", "goal_s"],
}


func test_registry_has_domain1(t) -> void:
	t.check(Modules.errors().is_empty(), "registry errors: %s" % str(Modules.errors()))
	var ids := Modules.by_domain("speed", true).map(func(m): return m.id)
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
