## Swap-in for D1-G2 (decision D-05) · Number Plate Check.
## Mechanism (fixed): two number plates — same or different? Themes change only
## the plate colours (private, commercial, electric).
extends GameModule

const LOOKALIKE := {"8": "B", "B": "8", "0": "D", "D": "0", "5": "S", "S": "5", "2": "Z", "Z": "2",
	"1": "7", "7": "1", "6": "G", "G": "6", "3": "8", "M": "N", "N": "M", "E": "F", "F": "E", "U": "V", "V": "U", "C": "G"}
const LETTERS := "ABCDEFGHJKLMNPRSTUVWXYZ"

var _plates: Array = []          # [{panel, label, cover}]
var _same_btn: Button
var _diff_btn: Button
var _is_same := true
var _change := ""


func _build() -> void:
	set_prompt(ctx.t("prompt"))
	var c := VBoxContainer.new()
	c.size_flags_vertical = SIZE_EXPAND_FILL
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_theme_constant_override("separation", Ui.s(36))
	stage.add_child(c)
	for i in 2:
		_plates.append(_make_plate(c))
	var row := Ui.hbox(18)
	stage.add_child(row)
	_same_btn = Ui.button(ctx.t("same"), "primary", Ui.SIZE_L, 150)
	_diff_btn = Ui.button(ctx.t("different"), "warm", Ui.SIZE_L, 150)
	for b in [_same_btn, _diff_btn]:
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(b)
	_same_btn.pressed.connect(_answer.bind(true))
	_diff_btn.pressed.connect(_answer.bind(false))


func _make_plate(parent: Control) -> Dictionary:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Ui.box(Color(str(ctx.theme.get_value("plate", "#ffffff"))), 16, Color("222222"), 5, 0))
	p.custom_minimum_size = Vector2(0, Ui.s(150))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	p.add_child(h)
	var strip := Label.new()
	strip.text = "IND"
	strip.custom_minimum_size.x = Ui.s(64)
	strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	strip.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	strip.add_theme_font_size_override("font_size", Ui.s(18))
	strip.add_theme_color_override("font_color", Color.WHITE)
	var sb := Ui.box(Color("1d3f91"), 0, Color.TRANSPARENT, 0, 8)
	sb.corner_radius_top_left = Ui.s(12)
	sb.corner_radius_bottom_left = Ui.s(12)
	strip.add_theme_stylebox_override("normal", sb)
	h.add_child(strip)
	var l := Label.new()
	l.size_flags_horizontal = SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", Ui.s(64))
	l.add_theme_color_override("font_color", Color(str(ctx.theme.get_value("ink", "#111111"))))
	if Ui.body_bold:
		l.add_theme_font_override("font", Ui.body_bold)
	h.add_child(l)
	var cover := ColorRect.new()
	cover.color = Ui.SLATE_SOFT
	cover.visible = false
	cover.mouse_filter = MOUSE_FILTER_IGNORE
	p.add_child(cover)
	parent.add_child(p)
	return {"panel": p, "label": l, "cover": cover}


func _present_trial(_lv: int, p: Dictionary, _i: int) -> void:
	var a := random_plate(ctx.rng)
	var change := str(p.change)
	if change == "mixed":
		change = ["lookalike", "transpose"][ctx.rng.randi_range(0, 1)]
	_is_same = ctx.rng.randf() < 0.5
	var b := a if _is_same else changed_plate(ctx.rng, a, change)
	_change = "none" if _is_same else change
	_plates[0].label.text = format_plate(a)
	_plates[1].label.text = format_plate(b)
	for pl in _plates:
		pl.cover.visible = false
		pl.panel.modulate.a = 0.0
		create_tween().tween_property(pl.panel, "modulate:a", 1.0, 0.15)
	_same_btn.disabled = false
	_diff_btn.disabled = false
	mark_onset()
	var exp := float(p.exposure_s)
	if exp > 0.0:
		after(exp, func():
			for pl in _plates:
				pl.cover.visible = true)
	after(maxf(20.0, goal_ms(p) / 1000.0 * 6.0), _on_idle)
	demo_tap(_same_btn if _is_same else _diff_btn, 1.4)


func _answer(said_same: bool) -> void:
	if _busy:
		return
	var rt := rt_ms()
	var p := ctx.params(level())
	var ok := said_same == _is_same
	var quick := rt <= goal_ms(p)
	_same_btn.disabled = true
	_diff_btn.disabled = true
	for pl in _plates:
		pl.cover.visible = false
	var kind := "correct" if ok else ("miss" if said_same else "false_alarm")
	complete_trial({
		"correct": ok, "kind": kind, "rt_ms": rt, "stair": ok and quick,
		"stimulus": {"plate_a": _plates[0].label.text, "plate_b": _plates[1].label.text, "same": _is_same, "change": _change, "exposure_s": float(p.exposure_s)},
		"response": {"said_same": said_same},
		"msg": (I18n.t("fb.great_speed") if quick else I18n.t("fb.correct")) if ok else (ctx.t("were_different") if not _is_same else ctx.t("were_same")),
		"wait": 0.8 if ok else 1.8,
	})


func _on_idle() -> void:
	if _busy:
		return
	_same_btn.disabled = true
	_diff_btn.disabled = true
	complete_trial({"correct": false, "kind": "omission", "rt_ms": -1,
		"stimulus": {"same": _is_same, "change": _change}, "response": {"reason": "idle"}, "wait": 1.2})


# ------------------------------------------------------------------ pure logic (unit-tested)
## Plate as an 10-char string: "TN" + district(2) + series(2) + number(4).
static func random_plate(rng: RandomNumberGenerator) -> String:
	var s := "TN%02d" % rng.randi_range(1, 99)
	for i in 2:
		s += LETTERS[rng.randi_range(0, LETTERS.length() - 1)]
	return s + "%04d" % rng.randi_range(1, 9999)


static func format_plate(p: String) -> String:
	return "%s %s %s %s" % [p.substr(0, 2), p.substr(2, 2), p.substr(4, 2), p.substr(6, 4)]


static func changed_plate(rng: RandomNumberGenerator, p: String, change: String) -> String:
	for _attempt in 60:
		var q := p
		match change:
			"obvious":
				q = "TN%02d" % rng.randi_range(1, 99) + p.substr(4)
				if q.substr(2, 2) == p.substr(2, 2) or absi(int(q.substr(2, 2)) - int(p.substr(2, 2))) < 10:
					continue
			"lookalike":
				var idx := []
				for i in range(2, p.length()):
					if LOOKALIKE.has(p[i]):
						idx.append(i)
				if idx.is_empty():
					var i2 := rng.randi_range(6, 9)
					q = p.substr(0, i2) + str((int(p[i2]) + 1) % 10) + p.substr(i2 + 1)
				else:
					var i3: int = idx[rng.randi_range(0, idx.size() - 1)]
					q = p.substr(0, i3) + LOOKALIKE[p[i3]] + p.substr(i3 + 1)
			"transpose":
				var i4 := rng.randi_range(2, p.length() - 2)
				if p[i4] == p[i4 + 1]:
					continue
				q = p.substr(0, i4) + p[i4 + 1] + p[i4] + p.substr(i4 + 2)
		if q != p:
			return q
	return p.substr(0, 9) + str((int(p[9]) + 1) % 10)
