## "I'm not feeling well" (feature F-01..F-05). Calm, no text walls, always one tap away.
## Records an alert for the clinic; offers Tele-MANAS (14416) and a breathing guide.
extends Screen

const TELE_MANAS := "14416"


func build() -> void:
	get_tree().paused = false
	App.in_session = false
	var alerts: Array = Store.get_value("alerts", [])
	alerts.append({"at": Time.get_datetime_string_from_system(true) + "Z", "context": params.get("context", ""), "kind": "not_well"})
	Store.set_value("alerts", alerts)
	var b := page(I18n.t("safety.title"), true)
	b.add_child(Ui.label(I18n.t("safety.calm"), Ui.SIZE_M, Ui.INK))
	var breath := BreathCircle.new()
	breath.color = Ui.SLATE
	breath.custom_minimum_size = Vector2(0, Ui.s(320))
	b.add_child(breath)
	b.add_child(Ui.label(I18n.t("safety.breathe"), Ui.SIZE_S, Ui.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	var call := Ui.button(I18n.t("safety.call", {"num": TELE_MANAS}), "primary", Ui.SIZE_M, 112, "phone")
	call.pressed.connect(func(): OS.shell_open("tel:" + TELE_MANAS))
	b.add_child(call)
	b.add_child(Ui.label(I18n.t("safety.clinic_told"), Ui.SIZE_S, Ui.MUTED))
	b.add_child(Ui.label(I18n.t("safety.emergency"), Ui.SIZE_S, Ui.SLATE, true))
	var home := Ui.button(I18n.t("safety.home"), "ghost", Ui.SIZE_M)
	home.pressed.connect(func(): App.go("home"))
	b.add_child(home)
