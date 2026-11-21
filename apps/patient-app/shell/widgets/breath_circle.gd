## Slow breathing guide: 4 s in, 6 s out. Calm motion well under 3 Hz.
class_name BreathCircle
extends Control

var color := Ui.TEAL
var _t := 0.0


func _process(d: float) -> void:
	_t += d
	queue_redraw()


func phase_in() -> bool:
	return fmod(_t, 10.0) < 4.0


func _draw() -> void:
	var k := fmod(_t, 10.0)
	var x := (k / 4.0) if k < 4.0 else (1.0 - (k - 4.0) / 6.0)
	x = 0.5 - 0.5 * cos(x * PI)
	var c := size / 2.0
	var rmax := minf(size.x, size.y) / 2.0 - 6
	draw_circle(c, rmax, Color(color, 0.10))
	draw_circle(c, rmax * (0.45 + 0.55 * x), Color(color, 0.35))
	draw_circle(c, rmax * 0.30, color)
