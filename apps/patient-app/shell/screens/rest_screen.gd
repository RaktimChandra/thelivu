## Short guided rest between games (feature D-06). Skippable.
extends Screen

var _left := 0.0
var _ring: RingProgress
var _total := 1.0
var _cue: Label
var _breath: BreathCircle


func build() -> void:
	var b := page()
	_total = float(Store.settings().get("rest_seconds", AppConfig.REST_SECONDS))
	_left = _total
	b.add_child(Ui.spacer(false, Ui.s(40)))
	b.add_child(Ui.title(I18n.t("rest.title"), Ui.SIZE_XL, Ui.INK, HORIZONTAL_ALIGNMENT_CENTER))
	_breath = BreathCircle.new()
	_breath.custom_minimum_size = Vector2(0, Ui.s(420))
	b.add_child(_breath)
	_cue = Ui.label("", Ui.SIZE_L, Ui.TEAL_DARK, true, HORIZONTAL_ALIGNMENT_CENTER)
	b.add_child(_cue)
	var nxt: String = params.get("next", "")
	if nxt != "":
		b.add_child(Ui.label(I18n.t("rest.next", {"name": I18n.t("%s.name" % nxt)}), Ui.SIZE_M, Ui.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	var go := Ui.button(I18n.t("rest.ready"), "primary", Ui.SIZE_L, 120)
	go.pressed.connect(_go)
	b.add_child(go)
	go.grab_focus.call_deferred()
	b.add_child(not_well_button("rest"))


func _process(d: float) -> void:
	_left -= d
	if _cue:
		_cue.text = I18n.t("rest.in") if _breath.phase_in() else I18n.t("rest.out")
	if _left <= 0.0:
		set_process(false)
		_go()


func _go() -> void:
	set_process(false)
	App.go("game", {"module_id": params.get("next", ""), "session": true})


func on_back() -> void:
	App.in_session = false
	App.go("home")
