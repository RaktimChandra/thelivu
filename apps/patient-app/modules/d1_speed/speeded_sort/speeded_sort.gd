## D1-G3 · Speeded Sorting.
## Mechanism (fixed): one item at a time; tap the bin it belongs to, following
## the sign (sort by colour, or by type). In "mixed" levels every bin shows a
## colour AND a type, so the item fits one bin by colour and another by type
## and the sign decides (cued rule switching). Themes swap objects and words only.
extends GameModule

const Token := preload("sort_token.gd")

var _sign: PanelContainer
var _sign_label: Label
var _sign_token: Control
var _item: Control
var _bins_row: HBoxContainer
var _bins: Array = []              # [{colour: int, kind: int, node: Button}]
var _bin_key := ""
var _rule := "colour"
var _since_switch := 0
var _answer := -1
var _item_colour := 0
var _item_kind := 0
var _congruent := true
var _switched := false
var _colours: Array = []
var _kinds: Array = []


func _build() -> void:
	_colours = ctx.theme.get_value("colours", [])
	_kinds = ctx.theme.get_value("kinds", [])
	set_prompt("")
	_sign = Ui.card(Ui.TEAL, 18, 22, Color.TRANSPARENT)
	var sh := Ui.hbox(16)
	_sign.add_child(sh)
	_sign_token = Token.new()
	_sign_token.custom_minimum_size = Vector2(Ui.s(72), Ui.s(72))
	sh.add_child(_sign_token)
	_sign_label = Ui.label("", Ui.SIZE_L, Color.WHITE, true)
	_sign_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sign_label.size_flags_horizontal = SIZE_EXPAND_FILL
	sh.add_child(_sign_label)
	stage.add_child(_sign)
	var c := CenterContainer.new()
	c.size_flags_vertical = SIZE_EXPAND_FILL
	stage.add_child(c)
	_item = Token.new()
	_item.custom_minimum_size = Vector2(Ui.s(250), Ui.s(250))
	_item.radius = 36
	c.add_child(_item)
	_bins_row = Ui.hbox(14)
	_bins_row.custom_minimum_size.y = Ui.s(210)
	stage.add_child(_bins_row)


func _present_trial(_lv: int, p: Dictionary, i: int) -> void:
	var k := mini(int(p.bins), mini(_colours.size(), _kinds.size()))
	var mode := str(p.rule)
	var key := "%d|%s" % [k, mode]
	if key != _bin_key:
		_bin_key = key
		_make_bins(k, mode)
		_since_switch = 0
		_rule = "kind" if mode == "kind" else "colour"
	# Rule for this trial ------------------------------------------------------
	_switched = false
	if mode == "mixed":
		var sw := int(p["switch"])
		var do_switch := (sw > 0 and _since_switch >= sw) or (sw < 0 and _since_switch >= 1 and ctx.rng.randf() < 0.33)
		if do_switch:
			_rule = "kind" if _rule == "colour" else "colour"
			_since_switch = 0
			_switched = true
	_since_switch += 1
	_set_sign()
	# Item ---------------------------------------------------------------------
	var pick := make_item(ctx.rng, _bins.map(func(b): return {"colour": b.colour, "kind": b.kind}), mode, _rule)
	_item_colour = pick.colour
	_item_kind = pick.kind
	_answer = pick.answer
	_congruent = pick.congruent
	var show_colour := mode != "kind"
	var show_kind := mode != "colour"
	_item.colour = Color(str(_colours[_item_colour].hex)) if show_colour else Color.TRANSPARENT
	_item.glyph = str(_colours[_item_colour].glyph) if show_colour else ""
	_item.icon = ctx.theme.texture(str(_kinds[_item_kind].id)) if show_kind else null
	_item.queue_redraw()
	_item.scale = Vector2(0.6, 0.6)
	_item.pivot_offset = _item.custom_minimum_size / 2.0
	_item.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_item, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_item, "modulate:a", 1.0, 0.12)
	for b in _bins:
		b.node.disabled = false
	mark_onset()
	after(maxf(20.0, goal_ms(p) / 1000.0 * 6.0), _on_idle)
	demo_tap(_bins[_answer].node, 1.3)


func _make_bins(k: int, mode: String) -> void:
	for b in _bins:
		b.node.queue_free()
	_bins.clear()
	var cols := range(_colours.size())
	var kinds := range(_kinds.size())
	cols = ctx.shuffled(cols).slice(0, k)
	kinds = ctx.shuffled(kinds).slice(0, k)
	for i in k:
		var b := Button.new()
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.focus_mode = FOCUS_NONE if demo else FOCUS_ALL
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.add_theme_stylebox_override("focus", Ui.box(Color.TRANSPARENT, 28, Ui.TURMERIC, 4))
		var t := Token.new()
		Ui.fill(t)
		t.mouse_filter = MOUSE_FILTER_IGNORE
		if mode != "kind":
			t.colour = Color(str(_colours[cols[i]].hex))
			t.glyph = str(_colours[cols[i]].glyph)
		if mode != "colour":
			t.icon = ctx.theme.texture(str(_kinds[kinds[i]].id))
		b.add_child(t)
		b.pressed.connect(_on_bin.bind(i))
		_bins_row.add_child(b)
		_bins.append({"colour": cols[i], "kind": kinds[i], "node": b, "token": t})


func _set_sign() -> void:
	var by_colour := _rule == "colour"
	_sign_label.text = ctx.t("by_colour") if by_colour else ctx.t("by_kind")
	_sign.add_theme_stylebox_override("panel", Ui.box(Ui.TEAL if by_colour else Ui.NIGHT, 22, Color.TRANSPARENT, 0, 18))
	_sign_token.palette = _colours.map(func(c): return Color(str(c.hex))) if by_colour else []
	_sign_token.colour = Color.TRANSPARENT
	_sign_token.glyph = ""
	_sign_token.icon = null if by_colour else ctx.theme.texture("rule")
	_sign_token.queue_redraw()
	if _switched:
		_sign.pivot_offset = _sign.size / 2.0
		_sign.scale = Vector2(1.06, 1.06)
		create_tween().tween_property(_sign, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)


func _on_bin(i: int) -> void:
	if _busy:
		return
	var rt := rt_ms()
	var p := ctx.params(level())
	var ok := i == _answer
	var quick := rt <= goal_ms(p)
	for b in _bins:
		b.node.disabled = true
	_flash(_bins[_answer].token, Ui.GOOD)
	if not ok:
		_flash(_bins[i].token, Ui.SLATE)
	complete_trial({
		"correct": ok, "kind": "correct" if ok else "wrong", "rt_ms": rt, "stair": ok and quick,
		"stimulus": {"rule": _rule, "switch": _switched, "congruent": _congruent, "bins": _bins.size(),
			"mode": str(p.rule), "colour": _colours[_item_colour].id, "item_kind": _kinds[_item_kind].id, "answer": _answer},
		"response": {"bin": i},
		"msg": (I18n.t("fb.great_speed") if quick else I18n.t("fb.correct")) if ok else (ctx.t("check_sign")),
		"wait": 0.7 if ok else 1.5,
	})


func _on_idle() -> void:
	if _busy:
		return
	var p := ctx.params(level())
	for b in _bins:
		b.node.disabled = true
	_flash(_bins[_answer].token, Ui.GOOD)
	complete_trial({"correct": false, "kind": "omission", "rt_ms": -1,
		"stimulus": {"rule": _rule, "switch": _switched, "congruent": _congruent, "bins": _bins.size(), "mode": str(p.rule)},
		"response": {"reason": "idle"}, "msg": ctx.t("check_sign"), "wait": 1.5})


func _flash(t: Control, col: Color) -> void:
	t.outline = col
	t.queue_redraw()
	after(0.6, func():
		t.outline = Ui.LINE
		t.queue_redraw())


# ------------------------------------------------------------------ pure logic (unit-tested)
## bins: [{colour, kind}]. Returns {colour, kind, answer, congruent}.
## Mixed mode: 75% conflict trials (colour points to one bin, kind to another).
static func make_item(rng: RandomNumberGenerator, bins: Array, mode: String, rule: String) -> Dictionary:
	var k := bins.size()
	var a := rng.randi_range(0, k - 1)
	if mode == "colour":
		return {"colour": bins[a].colour, "kind": bins[rng.randi_range(0, k - 1)].kind, "answer": a, "congruent": true}
	if mode == "kind":
		return {"colour": bins[rng.randi_range(0, k - 1)].colour, "kind": bins[a].kind, "answer": a, "congruent": true}
	var congruent := rng.randf() < 0.25
	var b := a
	if not congruent:
		b = (a + rng.randi_range(1, k - 1)) % k
	# a = bin matched by the active rule; b = bin matched by the other feature.
	if rule == "colour":
		return {"colour": bins[a].colour, "kind": bins[b].kind, "answer": a, "congruent": congruent}
	return {"colour": bins[b].colour, "kind": bins[a].kind, "answer": a, "congruent": congruent}
