## Base class for app screens: consistent page frame, top bar, scrolling body
## and bottom tab bar. Screens override build().
class_name Screen
extends Control

var screen_name := ""
var params: Dictionary = {}
var body: VBoxContainer


func build() -> void:
	pass


func leave() -> void:
	pass


func on_back() -> void:
	if screen_name != "home":
		App.go("home")


## Standard page: optional top bar + scrollable body (+ optional tabs).
func page(title_text := "", back := false, tabs := false) -> VBoxContainer:
	var root := Ui.vbox(0)
	Ui.fill(root)
	add_child(root)
	if title_text != "" or back:
		var bar := Ui.margin(Ui.PAD, 22, 6)
		var h := Ui.hbox(12)
		bar.add_child(h)
		if back:
			var b := Ui.button("", "ghost", Ui.SIZE_XL, 80, "back")
			b.custom_minimum_size.x = Ui.s(80)
			b.tooltip_text = I18n.t("common.back")
			b.pressed.connect(on_back)
			h.add_child(b)
		var t := Ui.title(title_text, Ui.SIZE_L)
		t.size_flags_horizontal = SIZE_EXPAND_FILL
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(t)
		root.add_child(bar)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var m := Ui.margin(Ui.PAD, 12, 32)
	m.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(m)
	body = Ui.vbox(22)
	body.size_flags_horizontal = SIZE_EXPAND_FILL
	m.add_child(body)
	if tabs:
		root.add_child(_tab_bar())
	return body


func _tab_bar() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Ui.box(Ui.PAPER, 0, Ui.LINE, 0, 10))
	var h := Ui.hbox(0)
	p.add_child(h)
	for t in [["home", "nav.home", "home"], ["library", "nav.activities", "grid"], ["progress", "nav.progress", "progress"], ["settings", "nav.settings", "settings"]]:
		var active: bool = t[0] == screen_name
		var b := Button.new()
		b.text = I18n.t(t[1])
		b.icon = Ui.icon(t[2])
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", Ui.s(40))
		b.flat = true
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.custom_minimum_size.y = Ui.s(104)
		b.add_theme_font_size_override("font_size", Ui.s(Ui.SIZE_XS))
		var col := Ui.TEAL if active else Ui.MUTED
		for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			b.add_theme_color_override(st, col)
		if active and Ui.body_bold:
			b.add_theme_font_override("font", Ui.body_bold)
		var dest: String = t[0]
		b.pressed.connect(func(): App.go(dest))
		h.add_child(b)
	return p


func not_well_button(context: String) -> Button:
	var b := Ui.button(I18n.t("safety.button"), "ghost", Ui.SIZE_S, 84, "heart")
	b.add_theme_stylebox_override("normal", Ui.box(Ui.SLATE_SOFT, Ui.RADIUS, Color("c9d6e6"), 2, 14))
	for st in ["font_color", "font_hover_color", "font_pressed_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(st, Ui.SLATE)
	b.pressed.connect(func(): Bus.safety_requested.emit(context))
	return b
