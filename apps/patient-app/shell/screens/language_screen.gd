## First run: choose a language. Native names only, so no reading of English is required.
extends Screen


func build() -> void:
	var b := page()
	b.add_child(Ui.spacer(false, Ui.s(80)))
	var logo := Ui.title("தெளிவு · Thelivu", Ui.SIZE_XL, Ui.TEAL_DARK, HORIZONTAL_ALIGNMENT_CENTER)
	b.add_child(logo)
	b.add_child(Ui.label("Choose your language · மொழியைத் தேர்ந்தெடுக்கவும் · भाषा चुनें", Ui.SIZE_S, Ui.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	b.add_child(Ui.spacer(false, Ui.s(40)))
	for code in I18n.SUPPORTED:
		var btn := Ui.button(I18n.NATIVE_NAMES[code], "ghost", Ui.SIZE_L, 128)
		btn.pressed.connect(_choose.bind(code))
		b.add_child(btn)
		if code == I18n.lang:
			btn.grab_focus.call_deferred()


func _choose(code: String) -> void:
	Sfx.tick()
	I18n.set_language(code)
	Store.set_value("profile.language", code)
	App.go(App.first_screen())


func on_back() -> void:
	pass
