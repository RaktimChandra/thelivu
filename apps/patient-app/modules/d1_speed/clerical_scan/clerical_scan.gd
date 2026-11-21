## D1-G1 · Rapid Clerical Scan.
## Mechanism (fixed): find the one line in a document that exactly matches the
## target. Themes change only the document's look and words (bus timetable,
## kirana price list, tablet schedule). Difficulty lives in levels.json.
extends GameModule

var _target_card: PanelContainer
var _target_label: Label
var _target_value: Label
var _goal_bar: ProgressBar
var _sheet: PanelContainer
var _rows_box: VBoxContainer
var _cant: Button
var _row_buttons: Array[Button] = []
var _answer := -1
var _labels: Array = []
var _goal_tween: Tween


func _build() -> void:
	_labels = ctx.theme.get_value("labels", [])
	set_prompt(ctx.t("prompt"))
	# Target card ---------------------------------------------------------------
	_target_card = Ui.card(Ui.NIGHT, 22, 22, Color.TRANSPARENT)
	var tv := Ui.vbox(10)
	_target_card.add_child(tv)
	var th := Ui.hbox(16)
	tv.add_child(th)
	var icon := TextureRect.new()
	icon.texture = ctx.theme.texture("icon")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(Ui.s(64), Ui.s(64))
	th.add_child(icon)
	_target_label = Ui.label("", Ui.SIZE_L, Color.WHITE, true, HORIZONTAL_ALIGNMENT_LEFT)
	_target_label.size_flags_horizontal = SIZE_EXPAND_FILL
	_target_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	th.add_child(_target_label)
	_target_value = Ui.label("", Ui.SIZE_XL, Ui.TURMERIC, true, HORIZONTAL_ALIGNMENT_RIGHT, false)
	if Ui.display_font:
		_target_value.add_theme_font_override("font", Ui.display_font)
	th.add_child(_target_value)
	_goal_bar = ProgressBar.new()
	_goal_bar.show_percentage = false
	_goal_bar.custom_minimum_size.y = Ui.s(8)
	_goal_bar.add_theme_stylebox_override("background", Ui.box(Color(1, 1, 1, 0.14), 99))
	_goal_bar.add_theme_stylebox_override("fill", Ui.box(Color(Ui.TURMERIC, 0.85), 99))
	tv.add_child(_goal_bar)
	stage.add_child(_target_card)
	# Document --------------------------------------------------------------------
	var paper := Color(str(ctx.theme.get_value("paper", "#ffffff")))
	_sheet = Ui.card(paper, 0, 18, Ui.LINE)
	_sheet.size_flags_vertical = SIZE_EXPAND_FILL
	var sv := Ui.vbox(0)
	_sheet.add_child(sv)
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", _top_box(Color(str(ctx.theme.get_value("accent", "#1e7568")))))
	var hl := Ui.label(ctx.theme.text("title"), Ui.SIZE_S, Color.WHITE, true)
	head.add_child(hl)
	sv.add_child(head)
	var cols := Ui.margin(18, 8, 4)
	var ch := Ui.hbox(8)
	cols.add_child(ch)
	var c1 := Ui.label(ctx.theme.text("col_label"), Ui.SIZE_XS, Ui.MUTED, true)
	c1.size_flags_horizontal = SIZE_EXPAND_FILL
	ch.add_child(c1)
	ch.add_child(Ui.label(ctx.theme.text("col_value"), Ui.SIZE_XS, Ui.MUTED, true, HORIZONTAL_ALIGNMENT_RIGHT, false))
	sv.add_child(cols)
	var rm := Ui.margin(8, 0, 8)
	rm.size_flags_vertical = SIZE_EXPAND_FILL
	sv.add_child(rm)
	_rows_box = Ui.vbox(4)
	rm.add_child(_rows_box)
	stage.add_child(_sheet)
	_cant = Ui.button(ctx.t("cant_find"), "ghost", Ui.SIZE_S, 76)
	_cant.pressed.connect(_on_cant_find)
	stage.add_child(_cant)


func _present_trial(_lv: int, p: Dictionary, _i: int) -> void:
	for b in _row_buttons:
		b.queue_free()
	_row_buttons.clear()
	var kind := str(ctx.theme.get_value("value_kind", "time"))
	var doc := make_document(ctx.rng, _labels.size(), kind, int(p.rows), int(p.sim), bool(p.sorted))
	_answer = doc.target_index
	var t: Dictionary = doc.rows[_answer]
	_target_label.text = ctx.theme.localized(_labels[t.label])
	_target_value.text = format_value(kind, t.value)
	var stripe := Color(str(ctx.theme.get_value("stripe", "#f2f2f2")))
	var paper := Color(str(ctx.theme.get_value("paper", "#ffffff")))
	var ink := Color(str(ctx.theme.get_value("ink", "#16302b")))
	for i in doc.rows.size():
		var r: Dictionary = doc.rows[i]
		var b := _row_button(ctx.theme.localized(_labels[r.label]), format_value(kind, r.value), int(p.font), stripe if i % 2 == 1 else paper, ink)
		b.pressed.connect(_on_row.bind(i))
		_rows_box.add_child(b)
		_row_buttons.append(b)
	_cant.disabled = false
	# Soft time goal: a calm bar that fills; nothing happens when it is full (D-04).
	_goal_bar.max_value = 1.0
	_goal_bar.value = 0.0
	if _goal_tween:
		_goal_tween.kill()
	_goal_tween = create_tween()
	_goal_tween.tween_property(_goal_bar, "value", 1.0, goal_ms(p) / 1000.0)
	_target_card.modulate.a = 0.0
	create_tween().tween_property(_target_card, "modulate:a", 1.0, 0.18)
	mark_onset()
	# Idle cap so an absent patient produces an omission instead of a stuck screen.
	after(maxf(30.0, goal_ms(p) / 1000.0 * 4.0), _on_idle)
	demo_tap(_row_buttons[_answer], 1.6)


func _on_row(i: int) -> void:
	if _busy:
		return
	var rt := rt_ms()
	var p := ctx.params(level())
	var ok := i == _answer
	var quick := rt <= goal_ms(p)
	_lock()
	_mark(_row_buttons[_answer], Ui.GOOD)
	if not ok:
		_mark(_row_buttons[i], Ui.SLATE)
	complete_trial({
		"correct": ok, "kind": "correct" if ok else "wrong", "rt_ms": rt,
		"stair": ok and quick,
		"stimulus": {"rows": int(p.rows), "sim": int(p.sim), "sorted": bool(p.sorted), "target_row": _answer},
		"response": {"row": i},
		"msg": (I18n.t("fb.great_speed") if quick else ctx.t("correct_slow")) if ok else ctx.t("wrong_line"),
		"wait": 1.0 if ok else 1.8,
	})


func _on_cant_find() -> void:
	_omission("cant_find")


func _on_idle() -> void:
	_omission("idle")


func _omission(reason: String) -> void:
	if _busy:
		return
	var p := ctx.params(level())
	_lock()
	_mark(_row_buttons[_answer], Ui.GOOD)
	complete_trial({
		"correct": false, "kind": "omission",
		"stimulus": {"rows": int(p.rows), "sim": int(p.sim), "sorted": bool(p.sorted), "target_row": _answer},
		"response": {"reason": reason},
		"msg": ctx.t("here_it_was"), "wait": 1.8,
	})


func _lock() -> void:
	if _goal_tween:
		_goal_tween.kill()
	_cant.disabled = true
	for b in _row_buttons:
		b.mouse_filter = MOUSE_FILTER_IGNORE


func _mark(b: Button, col: Color) -> void:
	var sb := Ui.box(Color(col, 0.16), 12, col, 4, 6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("disabled", sb)


func _row_button(label_text: String, value_text: String, font: int, bg: Color, ink: Color) -> Button:
	var b := Button.new()
	b.size_flags_vertical = SIZE_EXPAND_FILL
	b.custom_minimum_size.y = Ui.s(52)
	b.focus_mode = FOCUS_NONE if demo else FOCUS_ALL
	b.add_theme_stylebox_override("normal", Ui.box(bg, 12, Color.TRANSPARENT, 0, 6))
	b.add_theme_stylebox_override("hover", Ui.box(bg.darkened(0.03), 12, Color.TRANSPARENT, 0, 6))
	b.add_theme_stylebox_override("pressed", Ui.box(Color(Ui.TURMERIC, 0.25), 12, Color.TRANSPARENT, 0, 6))
	b.add_theme_stylebox_override("focus", Ui.box(Color.TRANSPARENT, 12, Ui.TURMERIC, 3, 6))
	var h := Ui.hbox(10)
	h.mouse_filter = MOUSE_FILTER_IGNORE
	Ui.fill(h)
	h.offset_left = Ui.s(14)
	h.offset_right = -Ui.s(14)
	b.add_child(h)
	var l := Ui.label(label_text, font, ink, false, HORIZONTAL_ALIGNMENT_LEFT, false)
	l.size_flags_horizontal = SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.mouse_filter = MOUSE_FILTER_IGNORE
	h.add_child(l)
	var v := Ui.label(value_text, font, ink, true, HORIZONTAL_ALIGNMENT_RIGHT, false)
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.mouse_filter = MOUSE_FILTER_IGNORE
	h.add_child(v)
	return b


func _top_box(c: Color) -> StyleBoxFlat:
	var sb := Ui.box(c, 0, Color.TRANSPARENT, 0, 16)
	sb.corner_radius_top_left = Ui.s(18)
	sb.corner_radius_top_right = Ui.s(18)
	return sb


# ------------------------------------------------------------------ pure logic (unit-tested)
## Build a document of `n` rows with exactly one row equal to the target.
## Returns {rows: [{label, value}], target_index}.
static func make_document(rng: RandomNumberGenerator, n_labels: int, kind: String, n: int, sim: int, sorted: bool) -> Dictionary:
	n = clampi(n, 2, n_labels)
	var target := {"label": rng.randi_range(0, n_labels - 1), "value": random_value(rng, kind)}
	var rows: Array = [target]
	var seen := {"%d|%d" % [target.label, target.value]: true}
	var other_labels := range(n_labels).filter(func(x): return x != target.label)
	for i in range(other_labels.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = other_labels[i]
		other_labels[i] = other_labels[j]
		other_labels[j] = tmp
	var share_label := 0
	var share_value := 0
	match sim:
		1:
			share_label = 1
		2:
			share_label = maxi(1, (n - 1) / 3)
			share_value = maxi(1, (n - 1) / 3)
		3:
			share_label = maxi(1, (n - 1) / 2)
			share_value = maxi(1, (n - 1) / 4)
	share_label = mini(share_label, n - 1)
	share_value = mini(share_value, n - 1 - share_label)
	var guard := 0
	while rows.size() < n and guard < 500:
		guard += 1
		var r := {}
		var made := rows.size() - 1
		if made < share_label:
			var v := mutate(rng, kind, target.value, sim >= 3 and rng.randf() < 0.5)
			r = {"label": target.label, "value": v}
		elif made < share_label + share_value and not other_labels.is_empty():
			r = {"label": other_labels.pop_back(), "value": target.value}
		elif not other_labels.is_empty():
			var base: int = target.value if sim >= 2 else random_value(rng, kind)
			var v2 := mutate(rng, kind, base, false) if sim >= 2 else base
			r = {"label": other_labels.pop_back(), "value": v2}
		else:
			r = {"label": rng.randi_range(0, n_labels - 1), "value": random_value(rng, kind)}
		var key := "%d|%d" % [r.label, r.value]
		if seen.has(key) or (r.label == target.label and r.value == target.value):
			continue
		seen[key] = true
		rows.append(r)
	if sorted:
		rows.sort_custom(func(a, b): return a.value < b.value or (a.value == b.value and a.label < b.label))
	else:
		for i in range(rows.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = rows[i]
			rows[i] = rows[j]
			rows[j] = tmp
	var ti := 0
	for i in rows.size():
		if rows[i].label == target.label and rows[i].value == target.value:
			ti = i
	return {"rows": rows, "target_index": ti}


static func random_value(rng: RandomNumberGenerator, kind: String) -> int:
	if kind == "price":
		return rng.randi_range(40, 980)
	return rng.randi_range(5, 22) * 100 + rng.randi_range(0, 11) * 5


static func valid(kind: String, v: int) -> bool:
	if kind == "price":
		return v >= 10 and v <= 999
	return v >= 0 and v / 100 <= 23 and v % 100 <= 59


static func digits(kind: String, v: int) -> String:
	return ("%03d" % v) if kind == "price" else ("%04d" % v)


## A look-alike value: one digit changed, or two neighbouring digits swapped.
static func mutate(rng: RandomNumberGenerator, kind: String, v: int, transpose: bool) -> int:
	var s := digits(kind, v)
	for _attempt in 40:
		var t := s
		if transpose:
			var i := rng.randi_range(0, s.length() - 2)
			if s[i] == s[i + 1]:
				continue
			t = s.substr(0, i) + s[i + 1] + s[i] + s.substr(i + 2)
		else:
			var i := rng.randi_range(0, s.length() - 1)
			var d := str((int(s[i]) + rng.randi_range(1, 9)) % 10)
			t = s.substr(0, i) + d + s.substr(i + 1)
		var nv := int(t)
		if nv != v and valid(kind, nv) and not (kind == "price" and t[0] == "0"):
			return nv
	return v + (5 if kind != "price" else 1)


static func format_value(kind: String, v: int) -> String:
	if kind == "price":
		return "₹ %d" % v
	return "%d:%02d" % [v / 100, v % 100] if v / 100 >= 10 else "0%d:%02d" % [v / 100, v % 100]
