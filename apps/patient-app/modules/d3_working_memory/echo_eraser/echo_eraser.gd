## D3-G1 · The Echo Eraser (working-memory updating, running span).
## Mechanism (fixed): items appear one at a time; the list stops without warning.
## Recall only the LAST k items, in order. Because the end is unknown, the patient
## must keep "erasing" the oldest item and holding the newest k (Pollack et al. 1959;
## Bunting, Cowan & Saults 2006). Themes swap the items: phone digits, fruit, vehicles.
extends GameModule

var _window_label: Label
var _display: PanelContainer
var _display_label: Label
var _display_icon: TextureRect
var _recall: SequenceRecall
var _stream: Array = []
var _target: Array = []
var _k := 2
var _items: Array = []


func _build() -> void:
	_items = ctx.theme.get_value("items", [])
	set_prompt("")
	_window_label = Ui.label("", Ui.SIZE_M, Ui.TEAL_DARK, true, HORIZONTAL_ALIGNMENT_CENTER)
	stage.add_child(_window_label)
	var c := CenterContainer.new()
	c.size_flags_vertical = SIZE_EXPAND_FILL
	stage.add_child(c)
	_display = PanelContainer.new()
	_display.custom_minimum_size = Vector2(Ui.s(320), Ui.s(320))
	_display.add_theme_stylebox_override("panel", Ui.box(Color(str(ctx.theme.get_value("tile", "#fbfcfb"))), 36, Ui.TEAL, 5))
	c.add_child(_display)
	_display_label = Ui.label("", Ui.SIZE_XXL, Color(str(ctx.theme.get_value("ink", "#16302b"))), true, HORIZONTAL_ALIGNMENT_CENTER, false)
	_display_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_display_label.add_theme_font_size_override("font_size", Ui.s(170))
	if Ui.display_font:
		_display_label.add_theme_font_override("font", Ui.display_font)
	_display.add_child(_display_label)
	_display_icon = TextureRect.new()
	_display_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_display.add_child(_display_icon)
	_recall = SequenceRecall.new()
	_recall.tile_color = Color(str(ctx.theme.get_value("tile", "#fbfcfb")))
	_recall.size_flags_vertical = SIZE_EXPAND_FILL
	_recall.visible = false
	_recall.submitted.connect(_on_submitted)
	stage.add_child(_recall)


func _present_trial(_lv: int, p: Dictionary, _i: int) -> void:
	_k = int(p.k)
	var n := ctx.rng.randi_range(int(p.len_lo), int(p.len_hi))
	_stream = make_stream(ctx.rng, _items.size(), n)
	_target = _stream.slice(_stream.size() - _k)
	_window_label.text = ctx.t("keep_last", {"k": _k})
	_recall.visible = false
	_display.get_parent().visible = true
	_show_item(0, float(p.show_s))


func _show_item(idx: int, show_s: float) -> void:
	if idx >= _stream.size():
		_start_recall()
		return
	var id: String = str(_items[_stream[idx]])
	var tex := ctx.theme.texture(id) if str(ctx.theme.get_value("kind", "digits")) == "icons" else null
	_display_icon.texture = tex
	_display_label.text = "" if tex else id
	_display.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_display, "modulate:a", 1.0, 0.12)
	tw.tween_interval(show_s * 0.7)
	tw.tween_property(_display, "modulate:a", 0.15, 0.12)
	Sfx.tick()
	after(show_s, _show_item.bind(idx + 1, show_s))


func _start_recall() -> void:
	_display.get_parent().visible = false
	_window_label.text = ctx.t("recall_last", {"k": _k})
	var opts := []
	var icons := str(ctx.theme.get_value("kind", "digits")) == "icons"
	for i in _items.size():
		var id := str(_items[i])
		opts.append({"id": str(i), "text": id, "icon": ctx.theme.texture(id) if icons else null})
	_recall.present(opts, _k)
	_recall.visible = true
	mark_onset()
	for j in _target.size():
		demo_tap(_recall.button_for(str(_target[j])), 1.0 + j * 1.1)


func _on_submitted(seq: Array) -> void:
	var rt := rt_ms()
	var answer := seq.map(func(s): return int(s))
	var score := score_positions(_target, answer)
	_recall.mark(score.per_item)
	var all_ok: bool = score.correct == _k
	complete_trial({
		"correct": all_ok, "kind": "correct" if all_ok else "wrong", "rt_ms": rt,
		"n": _k, "n_correct": score.correct,
		"stimulus": {"k": _k, "length": _stream.size(), "stream": _stream, "target": _target},
		"response": {"sequence": answer},
		"msg": I18n.t("fb.correct") if all_ok else ctx.t("partial", {"n": score.correct, "k": _k}),
		"wait": 1.4 if all_ok else 2.2,
	})


# ------------------------------------------------------------------ pure logic (unit-tested)
## A stream of item indexes with no immediate repeats.
static func make_stream(rng: RandomNumberGenerator, n_items: int, length: int) -> Array:
	var out := []
	for i in length:
		var v := rng.randi_range(0, n_items - 1)
		while not out.is_empty() and v == out[-1]:
			v = rng.randi_range(0, n_items - 1)
		out.append(v)
	return out


## Strict serial scoring: an item counts only in its own position.
static func score_positions(target: Array, answer: Array) -> Dictionary:
	var per := []
	var c := 0
	for i in target.size():
		var ok := i < answer.size() and int(answer[i]) == int(target[i])
		per.append(ok)
		if ok:
			c += 1
	return {"correct": c, "per_item": per}
