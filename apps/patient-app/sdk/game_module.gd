## Base class for every game module (SDK 1.0).
##
## A module implements four hooks; the base class runs the trial loop,
## adaptive difficulty, timing, telemetry, feedback and the result summary.
##
##   _build()                       create the module's persistent UI inside `stage`
##   _present_trial(level, p, i)    show one trial; call mark_onset() and later complete_trial()
##   _end_trial()                   optional cleanup between trials
##   play_demo(area)                optional animated demo for the instructions screen
##
## Pausing is done by the host with get_tree().paused; timers made with after()
## and tweens freeze with it, and response times exclude paused time.
class_name GameModule
extends Control

signal finished(result: Dictionary)

var ctx: GameContext
var stage: VBoxContainer          ## modules build their trial UI in here
var prompt: Label                 ## one line of instruction above the stage
var feedback: Label               ## gentle feedback under the stage

var _index := 0
var _token := 0
var _busy := false
var _finished := false
var _onset_us := 0
var _paused_us := 0
var _pause_start_us := 0
var _started_us := 0
var _level_start := 1
var _res := {}
var _banner: Label
## Demo mode: the module plays itself with an animated hand (instructions without text, R14).
var demo := false
var _hand: DemoHand


func setup(context: GameContext) -> void:
	ctx = context


func start() -> void:
	assert(ctx != null, "GameModule.start() called before setup()")
	if not demo:
		set_anchors_preset(PRESET_FULL_RECT)
	_level_start = ctx.staircase.level
	_res = {"trials": 0, "correct": 0, "omissions": 0, "commissions": 0, "rts": [], "seq": [],
		"stair_successes": 0, "stair_trials": 0}
	_started_us = Time.get_ticks_usec()
	_make_frame()
	_build()
	_next()


# ------------------------------------------------------------------ hooks
func _build() -> void:
	pass


func _present_trial(_level: int, _p: Dictionary, _i: int) -> void:
	push_error("%s must implement _present_trial()" % ctx.module_id)


func _end_trial() -> void:
	pass


## Animated, looping demo for the instructions screen (startup requirement R14).
## Default: the module plays itself; modules call demo_tap() in _present_trial.
func play_demo(_area: Control) -> void:
	demo = true
	Ui.fill_none(self)
	ctx.n_trials = 1000000
	mouse_filter = MOUSE_FILTER_IGNORE
	start()
	_hand = DemoHand.new()
	add_child(_hand)
	var blocker := Control.new()
	blocker.mouse_filter = MOUSE_FILTER_STOP
	Ui.fill(blocker)
	add_child(blocker)


## In demo mode, move the hand to `target` and press it after `delay` seconds.
func demo_tap(target: Control, delay := 1.1) -> void:
	if not demo:
		return
	var tok := _token
	after(delay, func():
		if _hand == null or not is_instance_valid(target):
			return
		var dest := target.get_global_rect().get_center() - get_global_rect().position
		_hand.move_to(dest, 0.55, func():
			if tok == _token and is_instance_valid(target) and target is BaseButton:
				(target as BaseButton).pressed.emit()))


# ------------------------------------------------------------------ API for modules
func level() -> int:
	return ctx.staircase.level


## Call when the stimulus becomes visible; response times are measured from here.
func mark_onset() -> void:
	_onset_us = _now_us()


func rt_ms() -> int:
	return int((_now_us() - _onset_us) / 1000)


func onset_ms() -> int:
	return int((_onset_us - _started_us) / 1000)


## Soft time goal for this level, in ms, after calibration/clinician scaling.
func goal_ms(p: Dictionary) -> int:
	return int(float(p.get("goal_s", 0.0)) * 1000.0 * ctx.goal_scale)


## Run fn after `sec` of unpaused time, unless the trial has moved on.
func after(sec: float, fn: Callable) -> void:
	var tok := _token
	get_tree().create_timer(sec, false).timeout.connect(func():
		if tok == _token and not _finished and is_inside_tree():
			fn.call())


## Report the outcome of the current trial.
## o keys: correct (bool, required); kind ("correct"|"wrong"|"omission"|"hit"|"miss"|"false_alarm"|"correct_reject");
## stimulus, response (Dictionaries); stair (bool, defaults to correct); n / n_correct (multi-item trials);
## msg (String); wait (seconds before next trial); quiet (no sound or message);
## no_stair (do not move the staircase, e.g. correct rejections in n-back).
func complete_trial(o: Dictionary) -> void:
	if _busy or _finished:
		return
	_busy = true
	var ok: bool = o.correct
	var stair_ok: bool = o.get("stair", ok)
	var kind: String = o.get("kind", "correct" if ok else "wrong")
	var rt := int(o.get("rt_ms", rt_ms()))
	var p := ctx.params(level())
	var trial := {
		"module_id": ctx.module_id, "module_version": ctx.module_version, "theme_id": ctx.theme.id,
		"level": level(), "index": _index, "practice": ctx.practice,
		"outcome": kind, "correct": ok, "rt_ms": rt, "t_onset_ms": onset_ms(),
		"soft_goal_ms": goal_ms(p), "stair_success": stair_ok,
		"stimulus": o.get("stimulus", {}), "response": o.get("response", {}),
	}
	if not demo:
		Telemetry.record(trial)
	_tally(kind, ok, rt, int(o.get("n", 1)), int(o.get("n_correct", 1 if ok else 0)))
	if not ctx.practice and not demo and not o.get("no_stair", false):
		_res.stair_trials += 1
		if stair_ok:
			_res.stair_successes += 1
		var before := level()
		var move := ctx.staircase.record(stair_ok)
		if move != "same":
			Bus.level_changed.emit(ctx.module_id, before, level())
		if move == "up":
			_show_level_up()
	if o.get("quiet", false):
		feedback.text = ""
	elif demo:
		say(o.get("msg", I18n.t("fb.correct")) if ok else "", Ui.GOOD)
	elif ok:
		Sfx.good()
		say(o.get("msg", I18n.t("fb.correct")), Ui.GOOD)
	else:
		Sfx.gentle()
		say(o.get("msg", I18n.t("fb.not_quite")), Ui.SLATE)
	_index += 1
	after(float(o.get("wait", 1.1)), _next)


func say(text: String, color := Ui.MUTED) -> void:
	feedback.text = text
	feedback.add_theme_color_override("font_color", color)
	feedback.modulate.a = 0.0
	create_tween().tween_property(feedback, "modulate:a", 1.0, 0.15)


func set_prompt(text: String) -> void:
	prompt.text = text


func clear_stage() -> void:
	for c in stage.get_children():
		c.queue_free()


func result() -> Dictionary:
	return _summary()


# ------------------------------------------------------------------ internals
func _next() -> void:
	if _finished:
		return
	_busy = false
	_token += 1
	if _index > 0:
		_end_trial()
	if _index >= ctx.n_trials:
		_finish()
		return
	feedback.text = ""
	var lv := level()
	_present_trial(lv, ctx.params(lv), _index)


func _finish() -> void:
	_finished = true
	var r := _summary()
	if demo:
		return
	Bus.game_finished.emit(ctx.module_id, r)
	finished.emit(r)


func _summary() -> Dictionary:
	var rts: Array = _res.rts.duplicate()
	rts.sort()
	var median := 0
	if not rts.is_empty():
		median = rts[rts.size() / 2] if rts.size() % 2 == 1 else int((rts[rts.size() / 2 - 1] + rts[rts.size() / 2]) / 2)
	var trials: int = _res.trials
	return {
		"module_id": ctx.module_id, "module_version": ctx.module_version, "theme_id": ctx.theme.id,
		"domain": ctx.manifest.domain, "practice": ctx.practice,
		"trials": trials, "correct": _res.correct, "omissions": _res.omissions, "commissions": _res.commissions,
		"accuracy": (float(_res.correct) / trials) if trials > 0 else 0.0,
		"rt_median_ms": median,
		"success_rate": (float(_res.stair_successes) / _res.stair_trials) if _res.stair_trials > 0 else 0.0,
		"level_start": _level_start, "level_end": ctx.staircase.level, "level_max": ctx.staircase.max_level,
		"active_ms": int((_now_us() - _started_us) / 1000), "seq": _res.seq.duplicate(),
	}


func _tally(kind: String, ok: bool, rt: int, n: int, n_correct: int) -> void:
	_res.trials += n
	_res.correct += n_correct
	match kind:
		"omission", "miss":
			_res.omissions += maxi(1, n - n_correct)
		"wrong", "false_alarm":
			_res.commissions += maxi(1, n - n_correct)
	if ok and rt >= AppConfig.MIN_VALID_RT_MS:
		_res.rts.append(rt)
	_res.seq.append(1 if ok else 0)


func _now_us() -> int:
	var paused_now := 0
	if _pause_start_us > 0:
		paused_now = Time.get_ticks_usec() - _pause_start_us
	return Time.get_ticks_usec() - _paused_us - paused_now


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_pause_start_us = Time.get_ticks_usec()
	elif what == NOTIFICATION_UNPAUSED and _pause_start_us > 0:
		_paused_us += Time.get_ticks_usec() - _pause_start_us
		_pause_start_us = 0


func _make_frame() -> void:
	var root := Ui.vbox(16)
	root.set_anchors_preset(PRESET_FULL_RECT)
	add_child(root)
	prompt = Ui.label("", Ui.SIZE_L, Ui.INK, true, HORIZONTAL_ALIGNMENT_CENTER)
	prompt.custom_minimum_size.y = Ui.s(56)
	root.add_child(prompt)
	stage = Ui.vbox(18)
	stage.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(stage)
	feedback = Ui.label("", Ui.SIZE_M, Ui.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER)
	feedback.custom_minimum_size.y = Ui.s(52)
	root.add_child(feedback)


func _show_level_up() -> void:
	Sfx.level_up()
	if _banner == null:
		_banner = Ui.label("", Ui.SIZE_S, Color("1a1406"), true, HORIZONTAL_ALIGNMENT_CENTER, false)
		_banner.add_theme_stylebox_override("normal", Ui.box(Ui.TURMERIC, 40, Color.TRANSPARENT, 0, 12))
		_banner.set_anchors_preset(PRESET_CENTER_TOP)
		add_child(_banner)
	_banner.text = I18n.t("fb.level_up", {"n": level()})
	_banner.reset_size()
	_banner.position = Vector2((size.x - _banner.size.x) / 2.0, -Ui.s(6))
	_banner.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.2)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.3)
