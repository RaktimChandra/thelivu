## Sign in with the Thelivu ID the clinic gives (built from name + date of birth,
## startup requirement R1) and a 4–6 digit PIN.
extends Screen

var _id: LineEdit
var _pin: LineEdit
var _err: Label


func build() -> void:
	var b := page()
	b.add_child(Ui.spacer(false, Ui.s(60)))
	b.add_child(Ui.title(I18n.t("signin.title"), Ui.SIZE_XL, Ui.TEAL_DARK))
	b.add_child(Ui.label(I18n.t("signin.sub"), Ui.SIZE_M, Ui.MUTED))
	b.add_child(Ui.spacer(false, Ui.s(16)))
	b.add_child(Ui.label(I18n.t("signin.id"), Ui.SIZE_S, Ui.INK, true))
	_id = _field("THL-…", false)
	b.add_child(_id)
	b.add_child(Ui.label(I18n.t("signin.pin"), Ui.SIZE_S, Ui.INK, true))
	_pin = _field("••••", true)
	_pin.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_pin.max_length = 6
	b.add_child(_pin)
	_err = Ui.label("", Ui.SIZE_S, Ui.SLATE)
	b.add_child(_err)
	var go := Ui.button(I18n.t("signin.go"), "primary", Ui.SIZE_L, 112)
	go.pressed.connect(_submit)
	_pin.text_submitted.connect(func(_t): _submit())
	b.add_child(go)
	var hint := Ui.card(Ui.TURMERIC_SOFT, 22, 18, Color.TRANSPARENT)
	hint.add_child(Ui.label(I18n.t("signin.demo_hint"), Ui.SIZE_S, Color("6a4a0e")))
	b.add_child(hint)
	var lang := Ui.button(I18n.NATIVE_NAMES[I18n.lang], "ghost", Ui.SIZE_S, 80, "globe")
	lang.pressed.connect(func(): App.go("language"))
	b.add_child(lang)


func _field(ph: String, secret: bool) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = ph
	e.secret = secret
	e.custom_minimum_size.y = Ui.s(96)
	e.add_theme_font_size_override("font_size", Ui.s(Ui.SIZE_L))
	return e


func _submit() -> void:
	if App.sign_in(_id.text, _pin.text):
		Sfx.good()
		App.go("home")
	else:
		Sfx.gentle()
		_err.text = I18n.t("signin.error")


func on_back() -> void:
	App.go("language")
