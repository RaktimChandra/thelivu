## D2-G1 · The Clock Test (sustained attention / vigilance).
## Mechanism (fixed, after Mackworth 1948): a hand moves one mark at a time;
## now and then it jumps TWO marks. Tap "Jump" when that happens. Targets become
## rarer and the marks finer as levels rise. Themes change only the dial's look.
##
## One trial = one step of the hand. A jump step's trial stays open for
## `window` steps (the hand keeps moving), so a slightly late tap still counts.
extends GameModule

var _dial: Dial
var _btn: Button
var _pos := 0
var _is_jump := false
var _answered := false
var _steps_since_jump := 99


func _build() -> void:
	set_prompt(ctx.t("prompt"))
	var c := CenterContainer.new()
	c.size_flags_vertical = SIZE_EXPAND_FILL
	stage.add_child(c)
	_dial = Dial.new()
	_dial.theme_data = ctx.theme.data
	_dial.custom_minimum_size = Vector2(Ui.s(560), Ui.s(560))
	c.add_child(_dial)
	_btn = Ui.button(ctx.t("jump"), "warm", Ui.SIZE_XL, 170)
	_btn.pressed.connect(_on_tap)
	stage.add_child(_btn)


func _present_trial(_lv: int, p: Dictionary, i: int) -> void:
	var ticks := int(p.ticks)
	_dial.ticks = ticks
	_answered = false
	# No jump in the first 3 steps, never two jumps in a row (keeps targets clear).
	_is_jump = i >= 3 and _steps_since_jump >= 2 and ctx.rng.randf() < float(p.p_jump)
	_steps_since_jump = 0 if _is_jump else _steps_since_jump + 1
	_pos = (_pos + (2 if _is_jump else 1)) % ticks
	_dial.move_to(_pos)
	mark_onset()
	var step := float(p.step_s)
	var window := int(p.window) if _is_jump else 1
	for k in range(1, window):
		after(step * k, func():
			_pos = (_pos + 1) % ticks
			_dial.move_to(_pos))
	after(step * window, _close.bind(p))
	if _is_jump:
		demo_tap(_btn, step * 0.55)


func _on_tap() -> void:
	if _answered or _busy:
		return
	_answered = true
	var p := ctx.params(level())
	var window := int(p.window) if _is_jump else 1
	var remaining := maxf(0.05, float(p.step_s) * window - rt_ms() / 1000.0)
	var stim := {"jump": _is_jump, "ticks": int(p.ticks), "step_s": float(p.step_s), "pos": _pos}
	if _is_jump:
		_dial.flash(Ui.GOOD)
		complete_trial({"correct": true, "kind": "hit", "stimulus": stim, "response": {"tap": true},
			"msg": I18n.t("fb.correct"), "wait": remaining})
	else:
		_dial.flash(Ui.SLATE)
		complete_trial({"correct": false, "kind": "false_alarm", "stimulus": stim, "response": {"tap": true},
			"msg": ctx.t("no_jump"), "wait": remaining})


func _close(p: Dictionary) -> void:
	if _answered or _busy:
		return
	_answered = true
	var stim := {"jump": _is_jump, "ticks": int(p.ticks), "step_s": float(p.step_s), "pos": _pos}
	if _is_jump:
		_dial.flash(Ui.TURMERIC)
		complete_trial({"correct": false, "kind": "miss", "rt_ms": -1, "stimulus": stim, "response": {"tap": false},
			"msg": ctx.t("missed"), "wait": 0.0})
	else:
		complete_trial({"correct": true, "kind": "correct_reject", "rt_ms": -1, "stimulus": stim,
			"response": {"tap": false}, "no_stair": true, "quiet": true, "wait": 0.0})


## Pure helper (unit-tested): expected number of targets in a block.
static func expected_targets(n: int, p_jump: float) -> float:
	return maxf(0.0, n - 3) * p_jump


class Dial extends Control:
	var theme_data: Dictionary = {}
	var ticks := 24
	var _angle := 0.0
	var _flash := Color.TRANSPARENT
	var _flash_a := 0.0

	func move_to(pos: int) -> void:
		var target := TAU * pos / ticks
		if target < _angle - 0.001:
			target += TAU   # keep turning clockwise across 12 o'clock
		var tw := create_tween()
		tw.tween_method(func(v): _angle = fmod(v, TAU); queue_redraw(), _angle, target, 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func flash(col: Color) -> void:
		_flash = col
		var tw := create_tween()
		tw.tween_method(func(v): _flash_a = v; queue_redraw(), 0.9, 0.0, 0.5)

	func _col(k: String, d: String) -> Color:
		return Color(str(theme_data.get(k, d)))

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 10.0
		var gauge := str(theme_data.get("style", "clock")) == "gauge"
		draw_circle(c, r, _col("rim", "#16302b"))
		draw_circle(c, r * 0.94, _col("face", "#fbfcfb"))
		if gauge:
			draw_arc(c, r * 0.80, -PI / 2, -PI / 2 + TAU, 128, Color(_col("rim", "#d49a33"), 0.35), r * 0.06, true)
		if _flash_a > 0.0:
			draw_arc(c, r * 0.97, 0, TAU, 96, Color(_flash, _flash_a), r * 0.07, true)
		var mark := _col("mark", "#4f625d")
		for k in ticks:
			var a := -PI / 2 + TAU * k / ticks
			var big := k % maxi(1, ticks / 12) == 0
			var r0 := r * (0.80 if big else 0.85)
			draw_line(c + Vector2(cos(a), sin(a)) * r0, c + Vector2(cos(a), sin(a)) * r * 0.90, mark, 5.0 if big else 2.5, true)
		var ha := -PI / 2 + _angle
		var tip := c + Vector2(cos(ha), sin(ha)) * r * 0.78
		var tail := c - Vector2(cos(ha), sin(ha)) * r * 0.12
		draw_line(tail, tip, _col("hand", "#16302b"), 9.0, true)
		draw_circle(tip, 7.0, _col("hand", "#16302b"))
		draw_circle(c, r * 0.07, _col("hub", "#d49a33"))
