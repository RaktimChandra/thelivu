## D1-G2 · Dynamic Velocity N-Back.
## Mechanism (fixed): items glide one at a time into a window; tap MATCH when the
## item is the same as the one n steps back. Stream speed (show_s + gap_s) is the
## main difficulty lever and follows the 3-down/1-up staircase (protocol deviation
## documented in THL-RES-001 §8.2). Themes swap the items only.
extends GameModule

const MATCH_RATE := 0.3
const SLIDE_S := 0.28

var _track: Panel
var _window: Panel
var _item: TextureRect
var _match_btn: Button
var _rule_chip: Label
var _interlude: Label
var _items: Array = []
var _history: Array = []        # item ids since the last n change
var _n := 0
var _is_match := false
var _answered := false
var _shown_at := 0.0


func _build() -> void:
	_items = ctx.theme.get_value("items", [])
	set_prompt("")
	_rule_chip = Ui.label("", Ui.SIZE_M, Ui.TEAL_DARK, true, HORIZONTAL_ALIGNMENT_CENTER, false)
	_rule_chip.add_theme_stylebox_override("normal", Ui.box(Ui.TEAL_SOFT, 99, Color.TRANSPARENT, 0, 14))
	_rule_chip.size_flags_horizontal = SIZE_SHRINK_CENTER
	stage.add_child(_rule_chip)
	var area := Control.new()
	area.size_flags_vertical = SIZE_EXPAND_FILL
	area.custom_minimum_size.y = Ui.s(360)
	area.clip_contents = true
	stage.add_child(area)
	_track = Panel.new()
	_track.add_theme_stylebox_override("panel", Ui.box(Color(str(ctx.theme.get_value("track", "#dde9e6"))), 26, Color(str(ctx.theme.get_value("track_edge", "#b5ccc6"))), 3))
	area.add_child(_track)
	_window = Panel.new()
	_window.add_theme_stylebox_override("panel", Ui.box(Color(str(ctx.theme.get_value("window", "#ffffff"))), 32, Ui.TURMERIC, 6))
	area.add_child(_window)
	_item = TextureRect.new()
	_item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_item.mouse_filter = MOUSE_FILTER_IGNORE
	area.add_child(_item)
	_interlude = Ui.label("", Ui.SIZE_XL, Ui.INK, true, HORIZONTAL_ALIGNMENT_CENTER)
	_interlude.add_theme_stylebox_override("normal", Ui.box(Color(Ui.PAPER, 0.96), 28, Ui.TEAL, 4, 24))
	_interlude.visible = false
	area.add_child(_interlude)
	area.resized.connect(_layout.bind(area))
	_layout.call_deferred(area)
	_match_btn = Ui.button(ctx.t("match"), "action", Ui.SIZE_XL, 170)
	_match_btn.pressed.connect(_on_match)
	stage.add_child(_match_btn)


func _layout(area: Control) -> void:
	var w := area.size.x
	var h := area.size.y
	var side := minf(h * 0.78, w * 0.46)
	_track.position = Vector2(0, h / 2.0 - side * 0.42)
	_track.size = Vector2(w, side * 0.84)
	_window.size = Vector2(side, side)
	_window.position = Vector2((w - side) / 2.0, (h - side) / 2.0)
	_item.size = Vector2(side * 0.74, side * 0.74)
	_item.position.y = (h - _item.size.y) / 2.0
	_interlude.size = Vector2(w * 0.86, 0)
	_interlude.position = Vector2(w * 0.07, h / 2.0 - Ui.s(70))


func _present_trial(_lv: int, p: Dictionary, _i: int) -> void:
	var n := int(p.n)
	if n != _n:
		var first := _n == 0
		_n = n
		_history.clear()
		_rule_chip.text = ctx.t("rule_%d" % n)
		if not first:
			# n changed mid-block: say so clearly, then restart the history (no hidden rule change).
			_interlude.text = ctx.t("now_rule_%d" % n)
			_interlude.visible = true
			_match_btn.disabled = true
			after(2.2, func():
				_interlude.visible = false
				_match_btn.disabled = false
				_show_item(p))
			return
	_show_item(p)


func _show_item(p: Dictionary) -> void:
	var pick := next_item(ctx.rng, _history, _n, mini(int(p.items), _items.size()), float(p.lure), _items, MATCH_RATE)
	_is_match = pick.match
	_answered = false
	_history.append(pick.id)
	_item.texture = ctx.theme.texture(pick.id)
	var area := _item.get_parent() as Control
	var w := area.size.x
	var cx := (w - _item.size.x) / 2.0
	_item.position.x = -_item.size.x
	_item.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_item, "position:x", cx, SLIDE_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_item, "modulate:a", 1.0, SLIDE_S * 0.6)
	_match_btn.disabled = false
	after(SLIDE_S * 0.5, mark_onset)
	after(SLIDE_S + float(p.show_s), _on_window_closed.bind(p))
	if _is_match:
		demo_tap(_match_btn, SLIDE_S + float(p.show_s) * 0.45)


func _on_match() -> void:
	if _answered or _busy:
		return
	_answered = true
	_match_btn.disabled = true
	var p := ctx.params(level())
	var ok := _is_match
	var stim := {"n": _n, "item": _history[-1], "is_match": _is_match, "items": int(p.items), "show_s": float(p.show_s)}
	_pulse_window(Ui.GOOD if ok else Ui.SLATE)
	# Keep the stream's pace: the next item comes when this one would have left.
	var remaining := maxf(0.15, SLIDE_S + float(p.show_s) - rt_ms() / 1000.0)
	after(remaining, _slide_out)
	complete_trial({
		"correct": ok, "kind": "hit" if ok else "false_alarm",
		"stimulus": stim, "response": {"tap": true},
		"msg": I18n.t("fb.correct") if ok else ctx.t("not_match"),
		"wait": remaining + SLIDE_S + float(p.gap_s),
	})


func _on_window_closed(p: Dictionary) -> void:
	if _answered or _busy:
		return
	_answered = true
	_match_btn.disabled = true
	_slide_out()
	var stim := {"n": _n, "item": _history[-1], "is_match": _is_match, "items": int(p.items), "show_s": float(p.show_s)}
	if _is_match:
		complete_trial({"correct": false, "kind": "miss", "stimulus": stim, "response": {"tap": false},
			"rt_ms": -1, "msg": ctx.t("missed"), "wait": SLIDE_S + float(p.gap_s)})
	else:
		complete_trial({"correct": true, "kind": "correct_reject", "stimulus": stim, "response": {"tap": false},
			"rt_ms": -1, "no_stair": true, "quiet": true, "wait": SLIDE_S + float(p.gap_s)})


func _slide_out() -> void:
	var area := _item.get_parent() as Control
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_item, "position:x", area.size.x + 10, SLIDE_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_item, "modulate:a", 0.0, SLIDE_S)


func _pulse_window(col: Color) -> void:
	var sb := Ui.box(Color(str(ctx.theme.get_value("window", "#ffffff"))), 32, col, 8)
	_window.add_theme_stylebox_override("panel", sb)
	after(0.45, func(): _window.add_theme_stylebox_override("panel", Ui.box(Color(str(ctx.theme.get_value("window", "#ffffff"))), 32, Ui.TURMERIC, 6)))


# ------------------------------------------------------------------ pure logic (unit-tested)
## Choose the next item. Returns {id, match}. A match is only possible once n items exist.
static func next_item(rng: RandomNumberGenerator, history: Array, n: int, k: int, lure: float, items: Array, match_rate: float) -> Dictionary:
	var pool: Array = items.slice(0, maxi(2, k))
	var can_match := history.size() >= n
	if can_match and rng.randf() < match_rate:
		return {"id": history[history.size() - n], "match": true}
	var forbidden: String = history[history.size() - n] if can_match else ""
	var choices := pool.filter(func(it): return it.id != forbidden)
	if can_match and lure > 0.0 and rng.randf() < lure:
		# Lure: an n-1 repeat (for n >= 2) or a look-alike of the n-back item.
		if n >= 2 and history[history.size() - 1] != forbidden:
			return {"id": history[history.size() - 1], "match": false}
		var group := ""
		for it in pool:
			if it.id == forbidden:
				group = it.group
		var alike := choices.filter(func(it): return it.group == group)
		if not alike.is_empty():
			return {"id": alike[rng.randi_range(0, alike.size() - 1)].id, "match": false}
	return {"id": choices[rng.randi_range(0, choices.size() - 1)].id, "match": false}
