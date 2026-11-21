## Design system for the patient app: tokens + small factory helpers.
## One place for colour, type and shape, so every screen and module looks like
## one product (no ad-hoc styling inside modules).
class_name Ui
extends RefCounted

# ---- colour tokens (calm, high-contrast; see docs/design/design-system.md)
const MIST := Color("e8f0ee")
const PAPER := Color("fbfcfb")
const INK := Color("16302b")
const MUTED := Color("4f625d")
const LINE := Color("d2deda")
const TEAL := Color("1e7568")
const TEAL_DARK := Color("165b51")
const TEAL_SOFT := Color("d3eae4")
const TURMERIC := Color("d49a33")
const TURMERIC_SOFT := Color("f6e7c8")
const NIGHT := Color("152f45")
const SLATE := Color("4f6585")
const SLATE_SOFT := Color("e3e9f3")
const GOOD := Color("2c7a4b")

# ---- type scale (px at 720-wide design viewport)
const SIZE_XS := 22
const SIZE_S := 26
const SIZE_M := 30
const SIZE_L := 38
const SIZE_XL := 52
const SIZE_XXL := 72

const RADIUS := 22
const PAD := 28

static var body_font: Font
static var body_bold: Font
static var display_font: Font
static var scale := 1.0


static func s(px: int) -> int:
	return int(round(px * scale))


static func box(bg: Color, radius := RADIUS, border := Color.TRANSPARENT, bw := 0, pad := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	sb.set_content_margin_all(pad)
	sb.anti_aliasing = true
	return sb


static func label(text: String, size := SIZE_M, color := INK, bold := false, align := HORIZONTAL_ALIGNMENT_LEFT, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", s(size))
	l.add_theme_color_override("font_color", color)
	if bold and body_bold:
		l.add_theme_font_override("font", body_bold)
	l.horizontal_alignment = align
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func title(text: String, size := SIZE_XL, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := label(text, size, color, false, align)
	if display_font:
		l.add_theme_font_override("font", display_font)
	return l


## Buttons: "primary" (teal), "soft" (teal tint), "ghost" (outline), "light" (white on dark).
static func button(text: String, kind := "primary", size := SIZE_M, min_h := 96, icon_name := "") -> Button:
	var b := Button.new()
	b.text = text
	if icon_name != "":
		b.icon = icon(icon_name)
		b.add_theme_constant_override("icon_max_width", s(int(size * 1.15)))
		b.add_theme_constant_override("h_separation", s(12))
	b.custom_minimum_size = Vector2(0, s(min_h))
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", s(size))
	if body_bold:
		b.add_theme_font_override("font", body_bold)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bg: Color
	var fg: Color
	var border := Color.TRANSPARENT
	match kind:
		"primary":
			bg = TEAL; fg = Color.WHITE
		"soft":
			bg = TEAL_SOFT; fg = TEAL_DARK
		"ghost":
			bg = PAPER; fg = INK; border = LINE
		"light":
			bg = PAPER; fg = TEAL_DARK
		"warm":
			bg = TURMERIC_SOFT; fg = Color("6a4a0e")
		_:
			bg = PAPER; fg = INK
	var bw := 3 if border != Color.TRANSPARENT else 0
	b.add_theme_stylebox_override("normal", box(bg, RADIUS, border, bw, 18))
	b.add_theme_stylebox_override("hover", box(bg.lightened(0.06), RADIUS, border, bw, 18))
	b.add_theme_stylebox_override("pressed", box(bg.darkened(0.08), RADIUS, border, bw, 18))
	b.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, RADIUS, TURMERIC, 4, 18))
	b.add_theme_stylebox_override("disabled", box(bg.lerp(MIST, 0.55), RADIUS, border, bw, 18))
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_color_override("font_disabled_color", fg.lerp(MIST, 0.4))
	for st in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(st, fg)
	return b


## White line icon from res://assets/icons (tinted by the control that shows it).
static func icon(name: String) -> Texture2D:
	var p := "res://assets/icons/%s.svg" % name
	return load(p) if ResourceLoader.exists(p) else null


static func card(bg := PAPER, pad := PAD, radius := RADIUS, border := LINE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, radius, border, 2 if border != Color.TRANSPARENT else 0, pad))
	return p


static func vbox(sep := 20) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", s(sep))
	return v


static func hbox(sep := 16) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", s(sep))
	return h


static func margin(px := PAD, top := -1, bottom := -1) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", s(px))
	m.add_theme_constant_override("margin_right", s(px))
	m.add_theme_constant_override("margin_top", s(px if top < 0 else top))
	m.add_theme_constant_override("margin_bottom", s(px if bottom < 0 else bottom))
	return m


static func spacer(expand := true, h := 0) -> Control:
	var c := Control.new()
	if expand:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size = Vector2(0, h)
	return c


static func fill(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	return c


## Keep a control's own size (used for scaled previews).
static func fill_none(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	return c
