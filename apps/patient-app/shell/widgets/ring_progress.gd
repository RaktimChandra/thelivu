## Circular progress ring with a centred number (today's minutes, a countdown).
class_name RingProgress
extends Control

var value := 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
var caption := ""
var check := false
var sub := ""
var track := Color(1, 1, 1, 0.16)
var fill_color := Ui.TURMERIC
var text_color := Color.WHITE
var _shown := 0.0


func _ready() -> void:
	create_tween().tween_property(self, "_shown", 1.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0 - Ui.s(12)
	var w := float(Ui.s(16))
	draw_arc(c, r, 0, TAU, 96, track, w, true)
	var v := value * _shown
	if v > 0.001:
		draw_arc(c, r, -PI / 2, -PI / 2 + TAU * v, maxi(8, int(96 * v)), fill_color, w, true)
	if check:
		var k := r * 0.42
		draw_polyline(PackedVector2Array([c + Vector2(-k, 0), c + Vector2(-k * 0.3, k * 0.7), c + Vector2(k, -k * 0.65)]), text_color, w * 0.9, true)
		return
	var f: Font = Ui.display_font if Ui.display_font else get_theme_default_font()
	var fs := Ui.s(Ui.SIZE_XL)
	var tw := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(c.x - tw / 2.0, c.y + fs * 0.22), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
	if sub != "":
		var f2: Font = Ui.body_font if Ui.body_font else f
		var fs2 := Ui.s(Ui.SIZE_XS)
		var sw := f2.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		draw_string(f2, Vector2(c.x - sw / 2.0, c.y + fs * 0.22 + fs2 * 1.3), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, text_color.darkened(0.15))
