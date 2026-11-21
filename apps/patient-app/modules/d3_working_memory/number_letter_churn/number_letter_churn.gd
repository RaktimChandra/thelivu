## D3-G3 · Number–Letter Churn (working-memory manipulation).
## Mechanism (fixed): numbers and letters appear one at a time, mixed. Then tap
## the NUMBERS from smallest to largest, then the LETTERS in alphabet order of the
## patient's own script (A B C · அ ஆ இ · अ आ इ). Visual, not spoken, and in the
## patient's script, so it differs from the MCCB Letter-Number Span (see THL-RES-004).
extends GameModule

var _guide: Label
var _display: PanelContainer
var _display_label: Label
var _recall: SequenceRecall
var _alphabet: Array = []
var _shown: Array = []
var _target: Array = []


func _build() -> void:
	_alphabet = I18n.list("%s.alphabet" % ctx.module_id)
	set_prompt("")
	_guide = Ui.label("", Ui.SIZE_M, Ui.TEAL_DARK, true, HORIZONTAL_ALIGNMENT_CENTER)
	stage.add_child(_guide)
	var c := CenterContainer.new()
	c.size_flags_vertical = SIZE_EXPAND_FILL
	stage.add_child(c)
	_display = PanelContainer.new()
	_display.custom_minimum_size = Vector2(Ui.s(300), Ui.s(300))
	_display.add_theme_stylebox_override("panel", Ui.box(Color(str(ctx.theme.get_value("show", "#d3eae4"))), 36, Ui.TEAL, 5))
	c.add_child(_display)
	_display_label = Ui.label("", Ui.SIZE_XXL, Color(str(ctx.theme.get_value("ink", "#16302b"))), true, HORIZONTAL_ALIGNMENT_CENTER, false)
	_display_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_display_label.add_theme_font_size_override("font_size", Ui.s(160))
	if Ui.display_font:
		_display_label.add_theme_font_override("font", Ui.display_font)
	_display.add_child(_display_label)
	_recall = SequenceRecall.new()
	_recall.tile_color = Color(str(ctx.theme.get_value("tile", "#fbfcfb")))
	_recall.ink = Color(str(ctx.theme.get_value("ink", "#16302b")))
	_recall.columns = 4
	_recall.size_flags_vertical = SIZE_EXPAND_FILL
	_recall.visible = false
	_recall.submitted.connect(_on_submitted)
	stage.add_child(_recall)


func _present_trial(_lv: int, p: Dictionary, _i: int) -> void:
	var s := make_set(ctx.rng, int(p.length), int(p.numbers), _alphabet)
	_shown = s.shown
	_target = s.ordered
	_guide.text = ctx.t("watch")
	_recall.visible = false
	_display.get_parent().visible = true
	_show(0, float(p.show_s), p)


func _show(idx: int, dur: float, p: Dictionary) -> void:
	if idx >= _shown.size():
		_start_recall(p)
		return
	_display_label.text = str(_shown[idx])
	_display.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_display, "modulate:a", 1.0, 0.12)
	tw.tween_interval(dur * 0.7)
	tw.tween_property(_display, "modulate:a", 0.15, 0.12)
	Sfx.tick()
	after(dur, _show.bind(idx + 1, dur, p))


func _start_recall(p: Dictionary) -> void:
	_display.get_parent().visible = false
	_guide.text = ctx.t("guide") if bool(p.guide) else ctx.t("recall")
	var pad: Array = _shown.duplicate()
	pad.append_array(make_decoys(ctx.rng, _shown, int(p.decoys), _alphabet))
	pad = ctx.shuffled(pad)
	_recall.present(pad.map(func(x): return {"id": str(x), "text": str(x)}), _target.size())
	_recall.visible = true
	mark_onset()
	for j in _target.size():
		demo_tap(_recall.button_for(str(_target[j])), 1.0 + j * 1.1)


func _on_submitted(seq: Array) -> void:
	var rt := rt_ms()
	var c := 0
	var per := []
	for i in _target.size():
		var ok := i < seq.size() and str(seq[i]) == str(_target[i])
		per.append(ok)
		if ok:
			c += 1
	_recall.mark(per)
	var all_ok := c == _target.size()
	complete_trial({
		"correct": all_ok, "kind": "correct" if all_ok else "wrong", "rt_ms": rt,
		"n": _target.size(), "n_correct": c,
		"stimulus": {"shown": _shown.map(func(x): return str(x)), "target": _target.map(func(x): return str(x))},
		"response": {"sequence": seq},
		"msg": I18n.t("fb.correct") if all_ok else ctx.t("answer_was", {"seq": "  ".join(PackedStringArray(_target.map(func(x): return str(x))))}),
		"wait": 1.4 if all_ok else 2.6,
	})


# ------------------------------------------------------------------ pure logic (unit-tested)
## shown: presentation order; ordered: correct answer (numbers ascending, then letters by alphabet index).
static func make_set(rng: RandomNumberGenerator, length: int, numbers: int, alphabet: Array) -> Dictionary:
	numbers = clampi(numbers, 0, length)
	var digits := range(1, 10)
	var nums := []
	while nums.size() < numbers:
		var d: int = digits[rng.randi_range(0, digits.size() - 1)]
		if d not in nums:
			nums.append(d)
	var lets := []
	var pool := alphabet.slice(0, mini(alphabet.size(), 12))   # common early letters keep the order learnable
	while lets.size() < length - numbers and lets.size() < pool.size():
		var l: String = pool[rng.randi_range(0, pool.size() - 1)]
		if l not in lets:
			lets.append(l)
	var shown := nums + lets
	for i in range(shown.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = shown[i]
		shown[i] = shown[j]
		shown[j] = t
	var sn := nums.duplicate()
	sn.sort()
	var sl := lets.duplicate()
	sl.sort_custom(func(a, b): return alphabet.find(a) < alphabet.find(b))
	return {"shown": shown, "ordered": sn + sl}


static func make_decoys(rng: RandomNumberGenerator, shown: Array, n: int, alphabet: Array) -> Array:
	var out := []
	var guard := 0
	while out.size() < n and guard < 100:
		guard += 1
		var v = rng.randi_range(1, 9) if rng.randf() < 0.5 else alphabet[rng.randi_range(0, mini(alphabet.size(), 12) - 1)]
		if v not in shown and v not in out:
			out.append(v)
	return out
