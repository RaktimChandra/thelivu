## D3-G2 · Vector Shifting (spatial working memory, updating).
## Mechanism (fixed): the token is shown on its start cell, then hidden. Arrows
## appear one at a time; move the token in your mind. Tap the cell where it ends.
## Unlike Spatial Span (an MCCB test), nothing is tapped in sequence: the skill is
## holding and updating one location. Themes change the board and token only.
extends GameModule

const DIRS := {"up": Vector2i(0, -1), "down": Vector2i(0, 1), "left": Vector2i(-1, 0), "right": Vector2i(1, 0)}

var _arrow: ArrowView
var _grid: GridContainer
var _cells: Array[Button] = []
var _n := 3
var _start := Vector2i.ZERO
var _end := Vector2i.ZERO
var _path: Array = []
var _token_tex: Texture2D
var _answering := false


func _build() -> void:
	_token_tex = ctx.theme.texture("token")
	set_prompt("")
	_arrow = ArrowView.new()
	_arrow.custom_minimum_size.y = Ui.s(200)
	_arrow.color = Color(str(ctx.theme.get_value("accent", "#1e7568")))
	stage.add_child(_arrow)
	var c := CenterContainer.new()
	c.size_flags_vertical = SIZE_EXPAND_FILL
	stage.add_child(c)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", Ui.s(8))
	_grid.add_theme_constant_override("v_separation", Ui.s(8))
	c.add_child(_grid)


func _present_trial(_lv: int, p: Dictionary, _i: int) -> void:
	_answering = false
	var n := int(p.grid)
	if n != _n or _cells.is_empty():
		_n = n
		_make_grid()
	var plan := make_path(ctx.rng, _n, int(p.moves), bool(p.double), bool(p.no_backtrack))
	_start = plan.start
	_path = plan.moves
	_end = plan.end
	_clear_cells()
	_cell(_start).icon = _token_tex
	_arrow.show_text(ctx.t("start_here"))
	after(1.6, func():
		_cell(_start).icon = null
		_play_arrow(0, float(p.arrow_s)))


func _play_arrow(i: int, dur: float) -> void:
	if i >= _path.size():
		_arrow.show_text(ctx.t("where_now"))
		_answering = true
		for b in _cells:
			b.disabled = false
		mark_onset()
		demo_tap(_cell(_end), 1.2)
		return
	var m: Dictionary = _path[i]
	_arrow.show_arrow(m.dir, m.steps, i + 1, _path.size())
	Sfx.tick()
	after(dur, _play_arrow.bind(i + 1, dur))


func _on_cell(pos: Vector2i) -> void:
	if not _answering or _busy:
		return
	_answering = false
	var rt := rt_ms()
	var ok := pos == _end
	for b in _cells:
		b.disabled = true
	_cell(_end).icon = _token_tex
	_paint(_end, Ui.GOOD)
	if not ok:
		_paint(pos, Ui.SLATE)
	var dist := absi(pos.x - _end.x) + absi(pos.y - _end.y)
	complete_trial({
		"correct": ok, "kind": "correct" if ok else "wrong", "rt_ms": rt,
		"stimulus": {"grid": _n, "start": [_start.x, _start.y], "moves": _path.map(func(m): return [m.dir, m.steps]), "end": [_end.x, _end.y]},
		"response": {"cell": [pos.x, pos.y], "distance": dist},
		"msg": I18n.t("fb.correct") if ok else (ctx.t("close") if dist == 1 else ctx.t("here_it_was")),
		"wait": 1.3 if ok else 2.0,
	})


func _make_grid() -> void:
	for b in _cells:
		b.queue_free()
	_cells.clear()
	_grid.columns = _n
	var size := Ui.s(clampi(600 / _n, 84, 170))
	for y in _n:
		for x in _n:
			var b := Button.new()
			b.custom_minimum_size = Vector2(size, size)
			b.expand_icon = true
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.focus_mode = FOCUS_NONE if demo else FOCUS_ALL
			b.add_theme_constant_override("icon_max_width", int(size * 0.62))
			b.pressed.connect(_on_cell.bind(Vector2i(x, y)))
			_grid.add_child(b)
			_cells.append(b)


func _clear_cells() -> void:
	for b in _cells:
		b.icon = null
		b.disabled = true
		_style(b, Color(str(ctx.theme.get_value("cell", "#fbfcfb"))), Color(str(ctx.theme.get_value("line", "#d2deda"))))


func _paint(pos: Vector2i, col: Color) -> void:
	_style(_cell(pos), Color(col, 0.18), col)


func _style(b: Button, bg: Color, edge: Color) -> void:
	for st in ["normal", "disabled"]:
		b.add_theme_stylebox_override(st, Ui.box(bg, 14, edge, 3))
	b.add_theme_stylebox_override("hover", Ui.box(bg.darkened(0.05), 14, Ui.TEAL, 3))
	b.add_theme_stylebox_override("pressed", Ui.box(Ui.TEAL_SOFT, 14, Ui.TEAL, 4))
	b.add_theme_stylebox_override("focus", Ui.box(Color.TRANSPARENT, 14, Ui.TURMERIC, 4))


func _cell(p: Vector2i) -> Button:
	return _cells[p.y * _n + p.x]


# ------------------------------------------------------------------ pure logic (unit-tested)
## Returns {start: Vector2i, moves: [{dir, steps}], end: Vector2i}; never leaves the grid.
static func make_path(rng: RandomNumberGenerator, n: int, moves: int, double: bool, no_backtrack: bool) -> Dictionary:
	for _attempt in 200:
		var start := Vector2i(rng.randi_range(0, n - 1), rng.randi_range(0, n - 1))
		var pos := start
		var out := []
		var prev := ""
		var ok := true
		for i in moves:
			var opts := []
			for d in DIRS:
				for steps in ([1, 2] if double and n >= 4 else [1]):
					var np: Vector2i = pos + DIRS[d] * steps
					if np.x < 0 or np.y < 0 or np.x >= n or np.y >= n:
						continue
					if no_backtrack and prev != "" and DIRS[d] == -DIRS[prev]:
						continue
					opts.append({"dir": d, "steps": steps})
			if opts.is_empty():
				ok = false
				break
			# Two-step arrows are a minority so they stay a surprise.
			var singles := opts.filter(func(o): return o.steps == 1)
			var pick: Dictionary = opts[rng.randi_range(0, opts.size() - 1)] if (singles.is_empty() or rng.randf() < 0.3) else singles[rng.randi_range(0, singles.size() - 1)]
			pos += DIRS[pick.dir] * int(pick.steps)
			prev = pick.dir
			out.append(pick)
		if ok and pos != start:
			return {"start": start, "moves": out, "end": pos}
	return {"start": Vector2i.ZERO, "moves": [{"dir": "right", "steps": 1}], "end": Vector2i(1, 0)}


## Big drawn arrow (no font glyphs needed) with an optional "x2" badge and a step counter.
class ArrowView extends Control:
	var color := Ui.TEAL
	var _dir := ""
	var _steps := 1
	var _text := ""
	var _count := ""
	var _a := 1.0

	func show_arrow(d: String, steps: int, i: int, total: int) -> void:
		_dir = d
		_steps = steps
		_text = ""
		_count = "%d / %d" % [i, total]
		_a = 0.0
		create_tween().tween_method(func(v): _a = v; queue_redraw(), 0.0, 1.0, 0.15)

	func show_text(t: String) -> void:
		_dir = ""
		_text = t
		_count = ""
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var f: Font = Ui.body_bold if Ui.body_bold else get_theme_default_font()
		if _dir == "":
			var fs := Ui.s(Ui.SIZE_L)
			var w := f.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, Vector2(c.x - w / 2.0, c.y + fs * 0.35), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Ui.INK)
			return
		var ang: float = {"right": 0.0, "down": PI / 2, "left": PI, "up": -PI / 2}[_dir]
		var L := minf(size.y * 0.42, 110.0)
		var pts := PackedVector2Array([Vector2(-L, -L * 0.18), Vector2(L * 0.25, -L * 0.18), Vector2(L * 0.25, -L * 0.48),
			Vector2(L, 0), Vector2(L * 0.25, L * 0.48), Vector2(L * 0.25, L * 0.18), Vector2(-L, L * 0.18)])
		var xf := Transform2D(ang, c)
		var col := Color(color, _a)
		draw_colored_polygon(xf * pts, col)
		if _steps > 1:
			var fs := Ui.s(Ui.SIZE_L)
			var t := "× %d" % _steps
			var bw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 28
			var bp := Vector2(c.x + L + 16, c.y - fs * 0.8)
			draw_style_box(Ui.box(Ui.TURMERIC, 99), Rect2(bp, Vector2(bw, fs * 1.6)))
			draw_string(f, bp + Vector2(14, fs * 1.15), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("1a1406"))
		var cs := Ui.s(Ui.SIZE_XS)
		draw_string(f, Vector2(8, cs + 4), _count, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, Ui.MUTED)
