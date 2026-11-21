## Settings: language, text size, sound, voice, sign out, about.
extends Screen


func build() -> void:
	var b := page(I18n.t("nav.settings"), false, true)
	var s := Store.settings()
	b.add_child(Ui.label(I18n.t("settings.language"), Ui.SIZE_S, Ui.MUTED, true))
	var lrow := Ui.hbox(12)
	b.add_child(lrow)
	for code in I18n.SUPPORTED:
		var lb := Ui.button(I18n.NATIVE_NAMES[code], "primary" if code == I18n.lang else "ghost", Ui.SIZE_S, 84)
		lb.size_flags_horizontal = SIZE_EXPAND_FILL
		lb.pressed.connect(func():
			I18n.set_language(code)
			Store.set_value("profile.language", code)
			App.go("settings"))
		lrow.add_child(lb)
	b.add_child(Ui.label(I18n.t("settings.text_size"), Ui.SIZE_S, Ui.MUTED, true))
	var trow := Ui.hbox(12)
	b.add_child(trow)
	for opt in [[1.0, "A"], [1.15, "A+"], [1.3, "A++"]]:
		var tb := Ui.button(opt[1], "primary" if is_equal_approx(float(s.text_scale), opt[0]) else "ghost", Ui.SIZE_M, 84)
		tb.size_flags_horizontal = SIZE_EXPAND_FILL
		var val: float = opt[0]
		tb.pressed.connect(func():
			s["text_scale"] = val
			Store.save()
			Bus.settings_changed.emit()
			App.go("settings"))
		trow.add_child(tb)
	b.add_child(_toggle("settings.sound", "sound"))
	b.add_child(_toggle("settings.voice", "voice"))
	var out := Ui.button(I18n.t("settings.sign_out"), "ghost", Ui.SIZE_M)
	out.pressed.connect(func():
		App.sign_out()
		App.go("signin"))
	b.add_child(out)
	var about := Ui.card(Ui.MIST, 22, 18, Ui.LINE)
	about.add_child(Ui.label(I18n.t("settings.about", {"v": AppConfig.APP_VERSION, "sdk": AppConfig.SDK_VERSION}), Ui.SIZE_XS, Ui.MUTED))
	b.add_child(about)
	if OS.is_debug_build():
		var reset := Ui.button(I18n.t("settings.reset_demo"), "ghost", Ui.SIZE_S, 76)
		reset.pressed.connect(func():
			Store.reset()
			App.go(App.first_screen()))
		b.add_child(reset)


func _toggle(label_key: String, setting: String) -> Control:
	var s := Store.settings()
	var row := Ui.hbox(12)
	var l := Ui.label(I18n.t(label_key), Ui.SIZE_M, Ui.INK)
	l.size_flags_horizontal = SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var on: bool = s.get(setting, true)
	var t := Ui.button(I18n.t("common.on") if on else I18n.t("common.off"), "primary" if on else "ghost", Ui.SIZE_S, 80)
	t.custom_minimum_size.x = Ui.s(150)
	t.pressed.connect(func():
		s[setting] = not on
		Store.save()
		App.go("settings"))
	row.add_child(t)
	return row
