## One day in the weekly streak: empty, signed in (outline) or session complete (filled).
class_name DayDot
extends Control

var state := "none"
var today := false
var letter := ""


func _draw() -> void:
	var r := minf(size.x, size.y * 0.7) / 2.0 - 4
	var c := Vector2(size.x / 2.0, r + 4)
	match state:
		"complete":
			draw_circle(c, r, Ui.TEAL)
			_check(c, r * 0.5, Color.WHITE)
		"signed_in":
			draw_arc(c, r - 2, 0, TAU, 48, Ui.TEAL, 4, true)
		_:
			draw_circle(c, r, Ui.MIST)
	if today:
		draw_arc(c, r + 3, 0, TAU, 48, Ui.TURMERIC, 3, true)
	if letter != "":
		var f: Font = Ui.body_font if Ui.body_font else get_theme_default_font()
		var fs := Ui.s(Ui.SIZE_XS)
		var w := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(c.x - w / 2.0, size.y - 2), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Ui.MUTED)


func _check(c: Vector2, s: float, col: Color) -> void:
	draw_polyline(PackedVector2Array([c + Vector2(-s, 0), c + Vector2(-s * 0.3, s * 0.65), c + Vector2(s, -s * 0.6)]), col, 5, true)
