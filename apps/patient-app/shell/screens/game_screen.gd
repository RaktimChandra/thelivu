## Hosts any game module: instructions (animated demo + voice, R14), optional
## practice, play with pause, then results. Works for every module through the SDK.
extends Screen

var module_id := ""
var in_session := false
var _phase := "intro"
var _module: GameModule
var _demo: GameModule
var _host: Control
var _bar: ProgressBar
var _pause_layer: Control
var _theme_id := ""
var _did_practice := false
const DEMO_SIZE := Vector2(620, 900)


func build() -> void:
	module_id = params.get("module_id", "")
	in_session = params.get("session", false)
	if not Modules.has(module_id):
		App.go("home")
		return
	_theme_id = App.module_theme(module_id)
	if params.get("autostart", false):
		_begin(false)
	else:
		_show_intro()


func leave() -> void:
	Voice.stop()
	get_tree().paused = false


func on_back() -> void:
	if _phase == "play":
		_pause(true)
	elif in_session:
		App.go("home")
	else:
		App.go("library")


# ------------------------------------------------------------------ intro
func _show_intro() -> void:
	_phase = "intro"
	_clear()
	var m := Modules.get_manifest(module_id)
	var b := page(I18n.t("%s.name" % module_id), true)
	if in_session and App.engine:
		b.add_child(Ui.label(I18n.t("game.session_step", {"n": App.engine.played.size() + 1}), Ui.SIZE_S, Ui.MUTED, true))
	var chip := Ui.label(I18n.t("domain.%s.name" % m.domain), Ui.SIZE_XS, Ui.TEAL_DARK, true, HORIZONTAL_ALIGNMENT_LEFT, false)
	chip.add_theme_stylebox_override("normal", Ui.box(Ui.TEAL_SOFT, 99, Color.TRANSPARENT, 0, 10))
	chip.size_flags_horizontal = SIZE_SHRINK_BEGIN
	b.add_child(chip)

	# Animated demo — the instructions are shown, not written.
	var demo_card := Ui.card(Ui.PAPER, 18)
	var area := Control.new()
	area.custom_minimum_size.y = Ui.s(660)
	area.clip_contents = true
	demo_card.add_child(area)
	b.add_child(demo_card)
	_demo = Modules.instantiate(module_id)
	if _demo:
		# The demo runs at full game size and is scaled into the card, so it looks
		# exactly like the real game (a live miniature, not a separate drawing).
		_demo.setup(GameContext.create(module_id, true, _theme_id))
		area.add_child(_demo)
		_demo.size = DEMO_SIZE
		area.resized.connect(_fit_demo.bind(area))
		_fit_demo.call_deferred(area)
		_demo.play_demo.call_deferred(area)

	var one_line := Ui.label(I18n.t("%s.goal" % module_id), Ui.SIZE_M, Ui.INK, false, HORIZONTAL_ALIGNMENT_CENTER)
	b.add_child(one_line)
	var listen := Ui.button(I18n.t("game.listen"), "soft", Ui.SIZE_M, 88, "speaker")
	listen.pressed.connect(_speak)
	b.add_child(listen)

	var themes: Array = m.themes
	if themes.size() > 1:
		b.add_child(Ui.label(I18n.t("game.choose_look"), Ui.SIZE_S, Ui.MUTED, true))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", Ui.s(12))
		row.add_theme_constant_override("v_separation", Ui.s(12))
		b.add_child(row)
		for t in themes:
			var tp := Modules.theme_pack(module_id, t)
			var tb := Ui.button(tp.text("name"), "primary" if t == _theme_id else "ghost", Ui.SIZE_S, 76)
			tb.autowrap_mode = TextServer.AUTOWRAP_OFF
			tb.custom_minimum_size.x = Ui.s(150)
			var tid: String = t
			tb.pressed.connect(func():
				_theme_id = tid
				App.set_module_theme(module_id, tid)
				_show_intro())
			row.add_child(tb)

	var plays := int(Store.module_state(module_id).plays)
	var actions := Ui.hbox(16)
	b.add_child(actions)
	var practice := Ui.button(I18n.t("game.practice"), "ghost", Ui.SIZE_M, 112)
	practice.size_flags_horizontal = SIZE_EXPAND_FILL
	practice.pressed.connect(_begin.bind(true))
	actions.add_child(practice)
	var start := Ui.button(I18n.t("game.start"), "primary", Ui.SIZE_M, 112)
	start.size_flags_horizontal = SIZE_EXPAND_FILL
	start.pressed.connect(_begin.bind(false))
	actions.add_child(start)
	(practice if plays == 0 and not _did_practice else start).grab_focus.call_deferred()
	b.add_child(Ui.label(I18n.t("%s.tip" % module_id), Ui.SIZE_S, Ui.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	_speak.call_deferred()


func _fit_demo(area: Control) -> void:
	if not is_instance_valid(_demo):
		return
	var k := minf(area.size.x / DEMO_SIZE.x, area.size.y / DEMO_SIZE.y)
	_demo.scale = Vector2(k, k)
	_demo.position = Vector2((area.size.x - DEMO_SIZE.x * k) / 2.0, (area.size.y - DEMO_SIZE.y * k) / 2.0)


func _speak() -> void:
	var lines := PackedStringArray(I18n.list("%s.voice" % module_id))
	if lines.is_empty():
		lines = PackedStringArray([I18n.t("%s.goal" % module_id)])
	Voice.speak(lines, Modules.get_manifest(module_id).dir, "intro")


# ------------------------------------------------------------------ play
func _begin(practice: bool) -> void:
	Voice.stop()
	Sfx.tick()
	_phase = "play"
	_did_practice = _did_practice or practice
	_clear()
	var root := Ui.vbox(0)
	Ui.fill(root)
	add_child(root)
	var top := Ui.margin(Ui.PAD, 18, 8)
	var h := Ui.hbox(16)
	top.add_child(h)
	var pause := Ui.button("", "ghost", Ui.SIZE_M, 80, "pause")
	pause.custom_minimum_size.x = Ui.s(96)
	pause.tooltip_text = I18n.t("game.pause")
	pause.pressed.connect(_pause.bind(true))
	h.add_child(pause)
	var mid := Ui.vbox(6)
	mid.size_flags_horizontal = SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(mid)
	mid.add_child(Ui.label(I18n.t("game.practice_round") if practice else I18n.t("%s.name" % module_id), Ui.SIZE_S, Ui.MUTED, true))
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size.y = Ui.s(14)
	mid.add_child(_bar)
	root.add_child(top)
	var m := Ui.margin(Ui.PAD, 8, Ui.PAD)
	m.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(m)
	_host = Control.new()
	m.add_child(_host)
	_module = Modules.instantiate(module_id)
	if _module == null:
		App.go("home")
		return
	_module.process_mode = PROCESS_MODE_PAUSABLE
	var ctx := GameContext.create(module_id, practice, _theme_id, App.module_level(module_id))
	_module.setup(ctx)
	_bar.max_value = ctx.n_trials
	_host.add_child(_module)
	_module.finished.connect(_on_finished)
	if not Bus.trial_recorded.is_connected(_on_trial):
		Bus.trial_recorded.connect(_on_trial)
	_module.start()


func _on_trial(_t: Dictionary) -> void:
	if _bar and is_instance_valid(_bar):
		create_tween().tween_property(_bar, "value", _bar.value + 1, 0.2)


func _pause(on: bool) -> void:
	if _phase != "play":
		return
	get_tree().paused = on
	if on:
		_pause_layer = _overlay()
		add_child(_pause_layer)
	elif _pause_layer:
		_pause_layer.queue_free()
		_pause_layer = null


func _overlay() -> Control:
	var layer := ColorRect.new()
	layer.color = Color(Ui.NIGHT, 0.88)
	Ui.fill(layer)
	var c := CenterContainer.new()
	Ui.fill(c)
	layer.add_child(c)
	var v := Ui.vbox(20)
	v.custom_minimum_size.x = Ui.s(560)
	c.add_child(v)
	v.add_child(Ui.title(I18n.t("game.paused"), Ui.SIZE_XL, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var resume := Ui.button(I18n.t("game.resume"), "warm", Ui.SIZE_L, 120)
	resume.pressed.connect(_pause.bind(false))
	v.add_child(resume)
	var again := Ui.button(I18n.t("game.instructions"), "light", Ui.SIZE_M)
	again.pressed.connect(func():
		get_tree().paused = false
		_show_intro())
	v.add_child(again)
	var stop := Ui.button(I18n.t("game.stop"), "light", Ui.SIZE_M)
	stop.pressed.connect(func():
		get_tree().paused = false
		App.in_session = false
		App.go("home"))
	v.add_child(stop)
	v.add_child(not_well_button("game:" + module_id))
	resume.grab_focus.call_deferred()
	return layer


# ------------------------------------------------------------------ results
func _on_finished(r: Dictionary) -> void:
	_phase = "review"
	if Bus.trial_recorded.is_connected(_on_trial):
		Bus.trial_recorded.disconnect(_on_trial)
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return
	_show_review(r)


func _show_review(r: Dictionary) -> void:
	_clear()
	Sfx.done()
	var b := page()
	b.add_child(Ui.spacer(false, Ui.s(30)))
	if r.practice:
		b.add_child(Ui.title(I18n.t("review.practice_done"), Ui.SIZE_XL))
		b.add_child(Ui.label(I18n.t("review.practice_sub"), Ui.SIZE_M, Ui.MUTED))
		var go := Ui.button(I18n.t("game.start"), "primary", Ui.SIZE_L, 120)
		go.pressed.connect(_begin.bind(false))
		b.add_child(go)
		var back := Ui.button(I18n.t("game.practice_again"), "ghost", Ui.SIZE_M)
		back.pressed.connect(_begin.bind(true))
		b.add_child(back)
		go.grab_focus.call_deferred()
		return
	var pts := App.points_for(r)
	b.add_child(Ui.title(I18n.t("review.well_done"), Ui.SIZE_XL))
	var card := Ui.card(Ui.NIGHT, 30, 28, Color.TRANSPARENT)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", Ui.s(20))
	g.add_theme_constant_override("v_separation", Ui.s(20))
	card.add_child(g)
	_stat(g, "%d%%" % roundi(float(r.accuracy) * 100.0), I18n.t("review.accuracy"))
	_stat(g, ("%.1f s" % (float(r.rt_median_ms) / 1000.0)) if int(r.rt_median_ms) > 0 else "–", I18n.t("review.typical_time"))
	_stat(g, "%d" % r.level_end, I18n.t("review.level", {"n": r.level_start}))
	_stat(g, "+%d" % pts, I18n.t("review.points"))
	b.add_child(card)
	var msg := I18n.t("review.level_up") if r.level_end > r.level_start else (I18n.t("review.steady") if r.level_end == r.level_start else I18n.t("review.eased"))
	b.add_child(Ui.label(msg, Ui.SIZE_M, Ui.INK, false))
	var tip := Ui.card(Ui.TURMERIC_SOFT, 20, 18, Color.TRANSPARENT)
	tip.add_child(Ui.label(I18n.t("%s.tip" % module_id), Ui.SIZE_S, Color("6a4a0e")))
	b.add_child(tip)
	if in_session and App.in_session:
		var next := Ui.button(I18n.t("review.continue"), "primary", Ui.SIZE_L, 120)
		next.pressed.connect(func(): App.continue_session(r))
		b.add_child(next)
		var end := Ui.button(I18n.t("review.end_for_today"), "ghost", Ui.SIZE_M)
		end.pressed.connect(func():
			App.engine.after_game(r.module_id, float(r.active_ms) / 60000.0, r.success_rate, r.level_end >= r.level_max)
			App.finish_session())
		b.add_child(end)
		next.grab_focus.call_deferred()
	else:
		var again := Ui.button(I18n.t("review.play_again"), "primary", Ui.SIZE_L, 120)
		again.pressed.connect(_begin.bind(false))
		b.add_child(again)
		var lib := Ui.button(I18n.t("review.back"), "ghost", Ui.SIZE_M)
		lib.pressed.connect(func(): App.go("library"))
		b.add_child(lib)
		again.grab_focus.call_deferred()


func _stat(g: GridContainer, big: String, small: String) -> void:
	var v := Ui.vbox(2)
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	v.add_child(Ui.title(big, Ui.SIZE_XL, Color.WHITE))
	v.add_child(Ui.label(small, Ui.SIZE_XS, Color("a9c6d8")))
	g.add_child(v)


func _clear() -> void:
	for c in get_children():
		c.queue_free()
	_pause_layer = null
