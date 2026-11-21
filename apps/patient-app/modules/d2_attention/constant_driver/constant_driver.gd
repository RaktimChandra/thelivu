## D2-G2 · The Constant Driver (selective attention, go/no-go).
## Mechanism (fixed): you follow a vehicle. Tap BRAKE when its brake lights come
## on (and, from level 5, when a speed-breaker sign appears). Do NOT brake for
## indicator lights or roadside boards. Events come at unpredictable times.
## Themes swap the vehicle and landscape only; fog and night are level settings.
extends GameModule

const EVENTS_GO := ["brake", "breaker"]

var _road: Road
var _btn: Button
var _event := ""
var _is_go := false
var _answered := false
var _active := false


func _build() -> void:
	set_prompt(ctx.t("prompt"))
	_road = Road.new()
	_road.theme_data = ctx.theme.data
	_road.size_flags_vertical = SIZE_EXPAND_FILL
	_road.custom_minimum_size.y = Ui.s(560)
	stage.add_child(_road)
	_btn = Ui.button(ctx.t("brake"), "action", Ui.SIZE_XL, 170)
	_btn.pressed.connect(_on_brake)
	stage.add_child(_btn)


func _present_trial(_lv: int, p: Dictionary, _i: int) -> void:
	_road.speed = float(p.speed)
	_road.fog = float(p.fog)
	_road.night = bool(p.night)
	_answered = false
	_active = false
	_event = pick_event(ctx.rng, bool(p.signs), float(p.lure))
	_is_go = _event in EVENTS_GO
	var lead := ctx.rng.randf_range(float(p.gap_lo), float(p.gap_hi))
	after(lead, _show_event.bind(p))


func _show_event(p: Dictionary) -> void:
	if _answered:
		return
	_active = true
	_road.show_event(_event, float(p.window_s))
	mark_onset()
	after(float(p.window_s), _close.bind(p))
	if _is_go:
		demo_tap(_btn, float(p.window_s) * 0.45)


func _on_brake() -> void:
	if _answered or _busy:
		return
	var p := ctx.params(level())
	if not _active:
		# Braking during plain driving: a false alarm with no event on screen.
		_answered = true
		_road.clear_event()
		complete_trial({"correct": false, "kind": "false_alarm", "rt_ms": -1,
			"stimulus": {"event": "none", "planned": _event}, "response": {"brake": true, "early": true},
			"msg": ctx.t("too_early"), "wait": 1.0})
		return
	_answered = true
	var rt := rt_ms()
	_road.clear_event()
	var stim := {"event": _event, "go": _is_go, "window_s": float(p.window_s), "fog": float(p.fog), "night": bool(p.night)}
	if _is_go:
		_road.pulse(Ui.GOOD)
		complete_trial({"correct": true, "kind": "hit", "rt_ms": rt, "stimulus": stim, "response": {"brake": true},
			"msg": I18n.t("fb.correct"), "wait": 0.6})
	else:
		_road.pulse(Ui.SLATE)
		complete_trial({"correct": false, "kind": "false_alarm", "rt_ms": rt, "stimulus": stim, "response": {"brake": true},
			"msg": ctx.t("no_brake_" + _event), "wait": 1.4})


func _close(p: Dictionary) -> void:
	if _answered or _busy:
		return
	_answered = true
	_road.clear_event()
	var stim := {"event": _event, "go": _is_go, "window_s": float(p.window_s), "fog": float(p.fog), "night": bool(p.night)}
	if _is_go:
		complete_trial({"correct": false, "kind": "miss", "rt_ms": -1, "stimulus": stim, "response": {"brake": false},
			"msg": ctx.t("missed_" + _event), "wait": 1.2})
	else:
		complete_trial({"correct": true, "kind": "correct_reject", "rt_ms": -1, "stimulus": stim,
			"response": {"brake": false}, "msg": ctx.t("good_ignore"), "wait": 0.5})


## Pure (unit-tested): choose the next event. Half go, half no-go.
static func pick_event(rng: RandomNumberGenerator, signs: bool, lure: float) -> String:
	if rng.randf() < 0.5:
		return "breaker" if signs and rng.randf() < 0.35 else "brake"
	return "indicator" if rng.randf() < lure else "board"


# ------------------------------------------------------------------ the scene
class Road extends Control:
	var theme_data: Dictionary = {}
	var speed := 1.0
	var fog := 0.0
	var night := false
	var _t := 0.0
	var _event := ""
	var _event_t := 0.0
	var _event_side := 1.0
	var _pulse := Color.TRANSPARENT
	var _pulse_a := 0.0

	func _process(d: float) -> void:
		_t += d * speed
		if _event != "":
			_event_t += d
		queue_redraw()

	func show_event(e: String, _dur: float) -> void:
		_event = e
		_event_t = 0.0
		_event_side = 1.0 if randf() < 0.5 else -1.0

	func clear_event() -> void:
		_event = ""

	func pulse(col: Color) -> void:
		_pulse = col
		create_tween().tween_method(func(v): _pulse_a = v, 0.8, 0.0, 0.45)

	func _c(k: String, d: String) -> Color:
		return Color(str(theme_data.get(k, d)))

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var hz := h * 0.36
		var sky := _c("sky", "#cfe3ef")
		var ground := _c("ground", "#b9c9a6")
		var road := _c("road", "#5b6470")
		if night:
			sky = Color("0d1a28")
			ground = Color("16241c")
			road = Color("1d232b")
		draw_style_box(Ui.box(sky, 22), Rect2(0, 0, w, h))
		draw_rect(Rect2(0, hz, w, h - hz), ground)
		# Road as a perspective trapezoid.
		var cx := w / 2.0
		draw_colored_polygon(PackedVector2Array([Vector2(cx - w * 0.06, hz), Vector2(cx + w * 0.06, hz), Vector2(w * 0.98, h), Vector2(w * 0.02, h)]), road)
		# Moving lane dashes (perspective: z from 0 far to 1 near).
		var dash := Color(1, 1, 1, 0.25 if night else 0.85)
		for k in 8:
			var z0 := fmod(k / 8.0 + _t * 0.35, 1.0)
			var z1 := minf(1.0, z0 + 0.05)
			var y0 := hz + (h - hz) * z0 * z0
			var y1 := hz + (h - hz) * z1 * z1
			var hw0 := 2.0 + 10.0 * z0
			var hw1 := 2.0 + 10.0 * z1
			draw_colored_polygon(PackedVector2Array([Vector2(cx - hw0, y0), Vector2(cx + hw0, y0), Vector2(cx + hw1, y1), Vector2(cx - hw1, y1)]), dash)
		# Roadside poles streaming past.
		for k in 5:
			var z := fmod(k / 5.0 + _t * 0.35, 1.0)
			var y := hz + (h - hz) * z * z
			var off := w * 0.08 + w * 0.42 * z * z
			var ph := 10.0 + 120.0 * z * z
			var pc := Color(0.85, 0.88, 0.9, 0.5) if night else Color("8c8f86")
			for s in [-1.0, 1.0]:
				draw_line(Vector2(cx + s * off, y), Vector2(cx + s * off, y - ph), pc, 2.0 + 4.0 * z)
		_draw_vehicle(Vector2(cx, hz + (h - hz) * 0.46), w * 0.30)
		if _event == "board" or _event == "breaker":
			_draw_sign(_event, hz, w, h)
		if fog > 0.0:
			draw_rect(Rect2(0, 0, w, h), Color(0.93, 0.95, 0.96, fog * 0.75))
		if _pulse_a > 0.0:
			draw_style_box(Ui.box(Color.TRANSPARENT, 22, Color(_pulse, _pulse_a), 10), Rect2(0, 0, w, h))

	func _draw_vehicle(base: Vector2, vw: float) -> void:
		var kind := str(theme_data.get("vehicle", "car"))
		var body := _c("body", "#2f5d8a")
		if night:
			body = body.darkened(0.75)
		var vh := vw * (0.95 if kind == "bus" else 0.62)
		var r := Rect2(base.x - vw / 2.0, base.y - vh, vw, vh)
		var sway := sin(_t * 2.2) * 2.0
		r.position.x += sway
		match kind:
			"bus":
				draw_style_box(Ui.box(body, 10), r)
				draw_style_box(Ui.box(Color("2a3a48"), 6), Rect2(r.position + Vector2(vw * 0.08, vh * 0.08), Vector2(vw * 0.84, vh * 0.38)))
			"auto":
				draw_style_box(Ui.box(Color("1f2a24"), int(vw * 0.35)), Rect2(r.position + Vector2(0, -vh * 0.25), Vector2(vw, vh * 0.7)))
				draw_style_box(Ui.box(body, 10), Rect2(r.position + Vector2(0, vh * 0.25), Vector2(vw, vh * 0.75)))
			_:
				draw_style_box(Ui.box(body.darkened(0.15), 16), Rect2(r.position + Vector2(vw * 0.12, -vh * 0.30), Vector2(vw * 0.76, vh * 0.5)))
				draw_style_box(Ui.box(Color("2a3a48"), 8), Rect2(r.position + Vector2(vw * 0.18, -vh * 0.24), Vector2(vw * 0.64, vh * 0.34)))
				draw_style_box(Ui.box(body, 12), r)
		# Number plate and wheels.
		draw_rect(Rect2(base.x + sway - vw * 0.13, base.y - vh * 0.32, vw * 0.26, vh * 0.14), Color("f2f2f2") if not night else Color("707070"))
		for s in [-1.0, 1.0]:
			draw_rect(Rect2(base.x + sway + s * vw * 0.36 - vw * 0.07, base.y - 4, vw * 0.14, vh * 0.12), Color("111111"))
		# Rear lights: dim, bright when braking, amber blink for an indicator (2 Hz, under the 3 Hz limit).
		var lw := vw * 0.13
		var ly := base.y - vh * 0.42
		for s in [-1.0, 1.0]:
			var lc := Color("6b1b1b") if not night else Color("4a1212")
			var glow := 0.0
			if _event == "brake":
				lc = Color("ff3b30")
				glow = 1.0
			elif _event == "indicator" and s == _event_side and fmod(_event_t, 0.5) < 0.25:
				lc = Color("ffa31a")
				glow = 0.8
			var lp := Vector2(base.x + sway + s * vw * 0.36, ly)
			if glow > 0.0:
				draw_circle(lp, lw * 1.3, Color(lc, 0.28 * glow))
			draw_style_box(Ui.box(lc, 6), Rect2(lp - Vector2(lw / 2.0, lw * 0.32), Vector2(lw, lw * 0.64)))

	func _draw_sign(kind: String, hz: float, w: float, h: float) -> void:
		var z := clampf(0.25 + _event_t * 0.35 * speed, 0.25, 0.95)
		var y := hz + (h - hz) * z * z
		var x := w / 2.0 + _event_side * (w * 0.10 + w * 0.36 * z * z)
		var s := 26.0 + 70.0 * z
		draw_line(Vector2(x, y), Vector2(x, y - s * 1.8), Color("7a7f86"), 4.0)
		var top := Vector2(x, y - s * 1.8)
		if kind == "breaker":
			# Yellow warning triangle with a hump: a go target.
			var tri := PackedVector2Array([top + Vector2(0, -s * 0.9), top + Vector2(s * 0.85, s * 0.55), top + Vector2(-s * 0.85, s * 0.55)])
			draw_colored_polygon(tri, Color("111111"))
			var inner := PackedVector2Array([top + Vector2(0, -s * 0.62), top + Vector2(s * 0.6, s * 0.40), top + Vector2(-s * 0.6, s * 0.40)])
			draw_colored_polygon(inner, Color("ffd21a"))
			draw_arc(top + Vector2(0, s * 0.32), s * 0.28, PI, TAU, 16, Color("111111"), 4.0)
		else:
			# Blue/green information board: a distractor.
			var col := Color("1d5fa8") if _event_side > 0 else Color("1e7a4c")
			draw_style_box(Ui.box(col, 6, Color.WHITE, 3), Rect2(top - Vector2(s * 0.9, s * 0.55), Vector2(s * 1.8, s * 1.0)))
			for k in 2:
				draw_line(top + Vector2(-s * 0.6, -s * 0.2 + k * s * 0.35), top + Vector2(s * 0.6, -s * 0.2 + k * s * 0.35), Color(1, 1, 1, 0.8), 3.0)
