## Application coordinator: theme, fonts, navigation, daily tracking and the
## session lifecycle. Screens and modules never call each other directly.
extends Node

var engine: SessionEngine
var in_session := false
var current_module := ""
var session_points := 0
var _fonts_ready := false


func _ready() -> void:
	_setup_fonts()
	_apply_text_scale()
	var lang := str(Store.get_value("profile.language", ""))
	if lang != "":
		I18n.set_language(lang)
	Bus.trial_recorded.connect(_on_trial)
	Bus.game_finished.connect(_on_game_finished)
	Bus.settings_changed.connect(_apply_text_scale)
	if signed_in():
		mark_signed_in_today()


# ------------------------------------------------------------------ navigation
func go(screen: String, params: Dictionary = {}) -> void:
	Bus.navigate.emit(screen, params)


func first_screen() -> String:
	if str(Store.get_value("profile.language", "")) == "":
		return "language"
	if not signed_in():
		return "signin"
	return "home"


# ------------------------------------------------------------------ identity
func signed_in() -> bool:
	return bool(Store.get_value("profile.signed_in", false))


## Demo sign-in. Production: POST /v1/auth/patient/login with Thelivu ID + PIN,
## device binding and lockout (features A-02, A-03, A-10).
func sign_in(thelivu_id: String, pin: String) -> bool:
	if thelivu_id.strip_edges().length() < 4 or pin.length() < 4:
		return false
	Store.set_value("profile.patient_id", thelivu_id.strip_edges().to_upper(), false)
	Store.set_value("profile.signed_in", true)
	if thelivu_id.to_upper().contains("DEMO"):
		prepare_demo_profile(I18n.lang)   # founder/clinic demos: show a realistic 2-week history
	mark_signed_in_today()
	return true


## Demo profile for deep links and screenshots: a signed-in "Meena" with some history.
func prepare_demo_profile(lang: String) -> void:
	I18n.set_language(lang)
	Store.set_value("profile.display_name", "Meena", false)
	Store.set_value("profile.patient_id", "THL-DEMO-01", false)
	Store.set_value("profile.signed_in", true)
	var days: Dictionary = Store.get_value("days", {})
	if days.size() < 3:
		var now := int(Time.get_unix_time_from_system())
		var mins := [32.0, 41.0, 0.0, 36.0, 44.0, 18.0, 12.0, 38.0, 45.0, 0.0, 30.0, 42.0, 35.0, 0.0]
		for i in mins.size():
			var key := Time.get_date_string_from_unix_time(now - (i + 1) * 86400)
			days[key] = {"signed_in": mins[i] > 0.0 or i % 5 == 0, "minutes": mins[i], "games": int(mins[i] / 6.0), "complete": mins[i] >= 30.0}
		Store.set_value("days", days)
		var d := Store.day()
		d["signed_in"] = true
		d["minutes"] = 14.0
		d["games"] = 2
		Store.add_domain_minutes("speed", 64.0)
		Store.add_domain_minutes("attention", 12.0)
	Store.save()


func sign_out() -> void:
	Store.set_value("profile.signed_in", false)


func display_name() -> String:
	var n := str(Store.get_value("profile.display_name", ""))
	return n if n != "" else I18n.t("common.friend")


## Startup requirement R2: was the patient signed in today?
func mark_signed_in_today() -> void:
	Store.day()["signed_in"] = true
	Store.save()


# ------------------------------------------------------------------ levels & stats
func module_level(id: String) -> int:
	var st := Store.module_state(id)
	var lv := int(st.level)
	if lv < 1:
		lv = int(Modules.get_manifest(id).get("start_level", 2))
	return lv


func module_theme(id: String) -> String:
	var t := str(Store.module_state(id).theme)
	return t if t != "" else str(Modules.get_manifest(id).default_theme)


func set_module_theme(id: String, theme_id: String) -> void:
	Store.module_state(id)["theme"] = theme_id
	Store.save()


## Rolling success over the last 20 counted items (feature E-04).
func module_success(id: String) -> float:
	var w: Array = Store.module_state(id).window
	if w.is_empty():
		return -1.0
	var s := 0.0
	for v in w:
		s += float(v)
	return s / w.size()


func _on_trial(trial: Dictionary) -> void:
	if trial.practice:
		return
	var st := Store.module_state(trial.module_id)
	var w: Array = st.window
	w.append(1 if trial.stair_success else 0)
	while w.size() > AppConfig.SUCCESS_WINDOW:
		w.pop_front()


func _on_game_finished(module_id: String, r: Dictionary) -> void:
	if r.practice:
		return
	var st := Store.module_state(module_id)
	st["level"] = r.level_end
	st["plays"] = int(st.plays) + 1
	st["last_result"] = {"accuracy": r.accuracy, "rt_median_ms": r.rt_median_ms, "active_ms": r.active_ms,
		"omissions": r.omissions, "commissions": r.commissions, "level_end": r.level_end,
		"at": Time.get_datetime_string_from_system()}
	var minutes := float(r.active_ms) / 60000.0
	var d := Store.day()
	d["minutes"] = float(d.minutes) + minutes
	d["games"] = int(d.games) + 1
	var s := Store.settings()
	d["complete"] = float(d.minutes) >= float(s.complete_min_minutes) or int(d.games) >= int(s.complete_min_games)
	Store.add_domain_minutes(r.domain, minutes)
	Store.save()


# ------------------------------------------------------------------ session
func build_engine() -> SessionEngine:
	var e := SessionEngine.new().configure(Store.settings())
	e.catalog = Modules.all().filter(func(m): return m.get("status", "official") == "official")
	for m in e.catalog:
		e.stats[m.id] = {"success": module_success(m.id), "at_ceiling": module_level(m.id) >= Modules.levels(m.id).size()}
	e.week_minutes = Store.week_domain_minutes().duplicate()
	return e


func start_session() -> void:
	engine = build_engine()
	engine.plan()
	in_session = true
	session_points = 0
	Telemetry.new_session()
	if engine.queue.is_empty():
		in_session = false
		go("home")
		return
	go("game", {"module_id": engine.queue[0], "session": true})


## Called by the review screen when a counted game in a session ends.
func continue_session(r: Dictionary) -> void:
	if not in_session:
		go("home")
		return
	var minutes := float(r.active_ms) / 60000.0
	var at_ceiling: bool = r.level_end >= r.level_max
	var nxt := engine.after_game(r.module_id, minutes, r.success_rate, at_ceiling)
	if nxt == "":
		finish_session()
	else:
		go("rest", {"next": nxt})


func finish_session() -> void:
	in_session = false
	Sfx.done()
	Bus.session_completed.emit({"games": engine.played.size(), "minutes": engine.minutes_played()})
	go("session_done", {"games": engine.played.size(), "minutes": engine.minutes_played()})


func points_for(r: Dictionary) -> int:
	var prev: Dictionary = Store.module_state(r.module_id).get("last_result", {})
	var pts := 10
	if not prev.is_empty() and int(r.rt_median_ms) > 0 and int(r.rt_median_ms) < int(prev.get("rt_median_ms", 0)):
		pts += 5
	if r.level_end > r.level_start:
		pts += 5
	return pts


# ------------------------------------------------------------------ look and feel
func _setup_fonts() -> void:
	var f := func(name: String) -> FontFile:
		var path := "res://assets/fonts/%s.woff2" % name
		return load(path) if ResourceLoader.exists(path) else null
	var body: FontFile = f.call("mukta-latin-400-normal")
	var bold: FontFile = f.call("mukta-latin-600-normal")
	var disp: FontFile = f.call("baloo-2-latin-600-normal")
	if body == null:
		return
	body.fallbacks = [f.call("mukta-devanagari-400-normal"), f.call("mukta-malar-tamil-400-normal")]
	bold.fallbacks = [f.call("mukta-devanagari-600-normal"), f.call("mukta-malar-tamil-600-normal")]
	disp.fallbacks = [f.call("baloo-2-devanagari-600-normal"), f.call("baloo-thambi-2-tamil-600-normal")]
	Ui.body_font = body
	Ui.body_bold = bold
	Ui.display_font = disp
	var th := Theme.new()
	th.default_font = body
	th.default_font_size = Ui.SIZE_M
	th.set_color("font_color", "Label", Ui.INK)
	th.set_stylebox("panel", "PanelContainer", Ui.box(Ui.PAPER, Ui.RADIUS, Ui.LINE, 2, Ui.PAD))
	th.set_stylebox("normal", "LineEdit", Ui.box(Ui.PAPER, 16, Ui.LINE, 3, 18))
	th.set_stylebox("focus", "LineEdit", Ui.box(Ui.PAPER, 16, Ui.TEAL, 3, 18))
	th.set_color("font_color", "LineEdit", Ui.INK)
	th.set_stylebox("background", "ProgressBar", Ui.box(Ui.LINE, 99))
	th.set_stylebox("fill", "ProgressBar", Ui.box(Ui.TEAL, 99))
	get_tree().root.theme = th
	_fonts_ready = true


func _apply_text_scale() -> void:
	Ui.scale = float(Store.settings().get("text_scale", 1.0))
