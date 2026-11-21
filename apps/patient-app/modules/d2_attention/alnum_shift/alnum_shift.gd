## D2-G3 · Alphanumeric Shift (attention switching).
## Mechanism (fixed): a card shows a number and a letter in its TOP or BOTTOM half.
##   Top half    → is the NUMBER odd or even?
##   Bottom half → is the LETTER a vowel or a consonant? (Tamil uyir/mei, Hindi svar/vyanjan, English)
## Left button = odd / vowel, right button = even / consonant. The position is the
## cue, so switching is never hidden. Themes change the card only.
extends GameModule

var _top: Panel
var _bottom: Panel
var _stim: Label
var _left: Button
var _right: Button
var _left_lines: Array[Label] = []
var _right_lines: Array[Label] = []
var _rule := "number"
var _prev_rule := ""
var _answer := 0           # 0 = left (odd / vowel), 1 = right (even / consonant)
var _congruent := true
var _vowels: Array = []
var _consonants: Array = []
var _stim_text := ""


func _build() -> void:
	_vowels = I18n.list("%s.vowels" % ctx.module_id)
	_consonants = I18n.list("%s.consonants" % ctx.module_id)
	set_prompt("")
	var card := PanelContainer.new()
	card.size_flags_vertical = SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", Ui.box(_c("paper", "#fbfcfb"), 30, _c("edge", "#d2deda"), 3, 14))
	stage.add_child(card)
	var v := Ui.vbox(10)
	card.add_child(v)
	_top = _half(v, _c("top", "#d3eae4"), ctx.t("top_cue"))
	_bottom = _half(v, _c("bottom", "#f6e7c8"), ctx.t("bottom_cue"))
	_stim = Ui.label("", Ui.SIZE_XXL, _c("ink", "#16302b"), true, HORIZONTAL_ALIGNMENT_CENTER, false)
	_stim.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stim.add_theme_font_size_override("font_size", Ui.s(110))
	if Ui.display_font:
		_stim.add_theme_font_override("font", Ui.display_font)
	var row := Ui.hbox(16)
	stage.add_child(row)
	_left = _answer_button(ctx.t("odd"), ctx.t("vowel"), _left_lines)
	_right = _answer_button(ctx.t("even"), ctx.t("consonant"), _right_lines)
	row.add_child(_left)
	row.add_child(_right)
	_left.pressed.connect(_on_answer.bind(0))
	_right.pressed.connect(_on_answer.bind(1))


func _c(k: String, d: String) -> Color:
	return Color(str(ctx.theme.get_value(k, d)))


func _half(parent: Control, col: Color, cue: String) -> Panel:
	var p := Panel.new()
	p.size_flags_vertical = SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", Ui.box(col, 22))
	parent.add_child(p)
	var l := Ui.label(cue, Ui.SIZE_XS, Ui.MUTED, true, HORIZONTAL_ALIGNMENT_LEFT, false)
	l.position = Vector2(Ui.s(18), Ui.s(12))
	p.add_child(l)
	return p


func _answer_button(line1: String, line2: String, store: Array[Label]) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	b.custom_minimum_size.y = Ui.s(170)
	b.focus_mode = FOCUS_NONE if demo else FOCUS_ALL
	b.add_theme_stylebox_override("normal", Ui.box(Ui.NIGHT, 24))
	b.add_theme_stylebox_override("hover", Ui.box(Ui.NIGHT.lightened(0.08), 24))
	b.add_theme_stylebox_override("pressed", Ui.box(Ui.TEAL, 24))
	b.add_theme_stylebox_override("disabled", Ui.box(Ui.NIGHT.lightened(0.25), 24))
	b.add_theme_stylebox_override("focus", Ui.box(Color.TRANSPARENT, 24, Ui.TURMERIC, 4))
	var v := Ui.vbox(4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = MOUSE_FILTER_IGNORE
	Ui.fill(v)
	b.add_child(v)
	for t in [line1, line2]:
		var l := Ui.label(t, Ui.SIZE_L, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER, false)
		l.mouse_filter = MOUSE_FILTER_IGNORE
		v.add_child(l)
		store.append(l)
	return b


func _present_trial(_lv: int, p: Dictionary, i: int) -> void:
	_prev_rule = _rule if i > 0 else ""
	_rule = pick_rule(ctx.rng, str(p.mode), i, _rule)
	var s := make_stimulus(ctx.rng, _rule, bool(p.pair), float(p.congruent_p), _vowels, _consonants)
	_answer = s.answer
	_congruent = s.congruent
	_stim_text = s.text
	_stim.text = s.text
	if _stim.get_parent():
		_stim.get_parent().remove_child(_stim)
	var host := _top if _rule == "number" else _bottom
	host.add_child(_stim)
	_stim.set_anchors_preset(PRESET_FULL_RECT)
	_stim.modulate.a = 0.0
	create_tween().tween_property(_stim, "modulate:a", 1.0, 0.1)
	# Hints: dim the words that do not matter for this card.
	var hint := bool(p.hint)
	for k in 2:
		var on := (k == 0) == (_rule == "number")
		_left_lines[k].modulate.a = 1.0 if (on or not hint) else 0.3
		_right_lines[k].modulate.a = 1.0 if (on or not hint) else 0.3
	_left.disabled = false
	_right.disabled = false
	mark_onset()
	after(maxf(10.0, goal_ms(p) / 1000.0 * 4.0), _on_idle)
	demo_tap(_left if _answer == 0 else _right, 1.2)


func _on_answer(side: int) -> void:
	if _busy:
		return
	var rt := rt_ms()
	var p := ctx.params(level())
	var ok := side == _answer
	var quick := rt <= goal_ms(p)
	_left.disabled = true
	_right.disabled = true
	var switched := _prev_rule != "" and _prev_rule != _rule
	var msg := (I18n.t("fb.great_speed") if quick else I18n.t("fb.correct")) if ok else ctx.t("wrong_" + _rule)
	complete_trial({
		"correct": ok, "kind": "correct" if ok else "wrong", "rt_ms": rt, "stair": ok and quick,
		"stimulus": {"rule": _rule, "switch": switched, "congruent": _congruent, "text": _stim_text, "mode": str(p.mode)},
		"response": {"side": side},
		"msg": msg, "wait": 0.6 if ok else 1.5,
	})


func _on_idle() -> void:
	if _busy:
		return
	_left.disabled = true
	_right.disabled = true
	complete_trial({"correct": false, "kind": "omission", "rt_ms": -1,
		"stimulus": {"rule": _rule, "text": _stim_text}, "response": {"reason": "idle"},
		"msg": ctx.t("wrong_" + _rule), "wait": 1.4})


# ------------------------------------------------------------------ pure logic (unit-tested)
static func pick_rule(rng: RandomNumberGenerator, mode: String, i: int, prev: String) -> String:
	match mode:
		"number":
			return "number"
		"letter":
			return "letter"
		"alt2":
			return "number" if (i / 2) % 2 == 0 else "letter"
	if prev == "":
		return "number"
	if rng.randf() < 0.5:
		return "letter" if prev == "number" else "number"
	return prev


## Returns {text, answer (0 left / 1 right), congruent}.
static func make_stimulus(rng: RandomNumberGenerator, rule: String, pair: bool, congruent_p: float, vowels: Array, consonants: Array) -> Dictionary:
	var target_side := rng.randi_range(0, 1)
	var digit := 0
	var letter := ""
	var congruent := true
	# Side for the irrelevant character: same as the target's (congruent) or the other.
	var other_side := target_side
	if pair:
		congruent = rng.randf() < congruent_p
		other_side = target_side if congruent else 1 - target_side
	var num_side := target_side if rule == "number" else other_side
	var let_side := target_side if rule == "letter" else other_side
	var odds := [1, 3, 5, 7, 9]
	var evens := [2, 4, 6, 8]
	digit = odds[rng.randi_range(0, 4)] if num_side == 0 else evens[rng.randi_range(0, 3)]
	var pool: Array = vowels if let_side == 0 else consonants
	letter = str(pool[rng.randi_range(0, pool.size() - 1)]) if not pool.is_empty() else "A"
	var text := ""
	if not pair:
		text = str(digit) if rule == "number" else letter
	else:
		text = ("%d  %s" % [digit, letter]) if rng.randf() < 0.5 else ("%s  %d" % [letter, digit])
	return {"text": text, "answer": target_side, "congruent": congruent}
