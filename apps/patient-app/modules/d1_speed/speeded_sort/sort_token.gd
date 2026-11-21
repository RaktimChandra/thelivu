## Visual for an item or a bin: an optional coloured card with a shape mark
## (colour is never the only cue — colour-blind safe), and an optional object icon.
extends Control

var colour := Color.TRANSPARENT     # TRANSPARENT = no colour feature shown
var glyph := ""                     # circle | triangle | square | star
var icon: Texture2D
var outline := Ui.LINE
var radius := 26.0
var palette: Array = []             # if set: draw these colours as a 2x2 swatch (the "by colour" sign)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bg := colour if colour.a > 0.0 else Ui.PAPER
	var sb := Ui.box(bg, int(radius), outline, 3)
	draw_style_box(sb, r)
	var s := minf(size.x, size.y)
	if not palette.is_empty():
		var pad := s * 0.14
		var cell := (s - pad * 2.0 - s * 0.06) / 2.0
		for i in mini(4, palette.size()):
			var pos := Vector2(pad + (i % 2) * (cell + s * 0.06), pad + (i / 2) * (cell + s * 0.06))
			draw_style_box(Ui.box(palette[i], int(cell * 0.25)), Rect2(pos, Vector2(cell, cell)))
		return
	if icon:
		var disc := s * 0.36
		var c := size / 2.0
		if colour.a > 0.0:
			draw_circle(c, disc, Color.WHITE)
		var isz := disc * 1.45
		draw_texture_rect(icon, Rect2(c - Vector2(isz, isz) / 2.0, Vector2(isz, isz)), false)
	if glyph != "" and colour.a > 0.0:
		if icon:
			var g := s * 0.11
			_glyph(Vector2(g * 1.7, g * 1.7), g, Color.WHITE)
		else:
			_glyph(size / 2.0, s * 0.22, Color(1, 1, 1, 0.92))


func _glyph(c: Vector2, r: float, col: Color) -> void:
	match glyph:
		"circle":
			draw_circle(c, r, col)
		"square":
			draw_rect(Rect2(c - Vector2(r, r) * 0.9, Vector2(r, r) * 1.8), col)
		"triangle":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 1.05, r * 0.8), c + Vector2(-r * 1.05, r * 0.8)]), col)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2 + i * PI / 5
				var rr := r * (1.15 if i % 2 == 0 else 0.5)
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, col)
