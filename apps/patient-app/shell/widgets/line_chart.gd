## Minimal, legible line chart for patient-facing progress (R11).
## Shows one series, labelled first/last values, no gridline clutter.
class_name LineChart
extends Control

var values: Array = []          # floats; NAN = no data that day
var labels: Array = []          # x labels (first and last are drawn)
var color := Ui.TEAL
var unit := ""
var lower_is_better := false


func _draw() -> void:
	var pad := Vector2(Ui.s(16), Ui.s(30))
	var w := size.x - pad.x * 2
	var h := size.y - pad.y * 2
	draw_line(Vector2(pad.x, size.y - pad.y), Vector2(size.x - pad.x, size.y - pad.y), Ui.LINE, 2)
	var pts := []
	var vmax := 0.0
	var vmin := INF
	for v in values:
		if not is_nan(float(v)):
			vmax = maxf(vmax, float(v))
			vmin = minf(vmin, float(v))
	var f: Font = Ui.body_font if Ui.body_font else get_theme_default_font()
	var fs := Ui.s(Ui.SIZE_XS)
	if vmax <= 0.0 and vmin == INF:
		var msg := I18n.t("progress.no_data")
		draw_string(f, Vector2(pad.x, size.y / 2.0), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Ui.MUTED)
		return
	var lo := minf(0.0, vmin)
	var span := maxf(0.001, vmax - lo)
	for i in values.size():
		var v := float(values[i])
		if is_nan(v):
			continue
		var x := pad.x + (w * i / maxf(1.0, values.size() - 1.0))
		var y := pad.y + h - (v - lo) / span * h
		pts.append(Vector2(x, y))
	if pts.size() >= 2:
		draw_polyline(PackedVector2Array(pts), color, 4, true)
	for p in pts:
		draw_circle(p, Ui.s(6), color)
	if not pts.is_empty():
		var last: Vector2 = pts[-1]
		var txt := "%s%s" % [_fmt(float(values[values.size() - 1]) if not is_nan(float(values[-1])) else 0.0), unit]
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tp := Vector2(minf(last.x - tw / 2.0, size.x - tw - 4), maxf(fs + 2.0, minf(last.y - Ui.s(16), pad.y)))
		draw_style_box(Ui.box(Ui.PAPER, 8), Rect2(tp - Vector2(6, fs), Vector2(tw + 12, fs * 1.35)))
		draw_string(f, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Ui.INK)
	if labels.size() >= 2:
		draw_string(f, Vector2(pad.x, size.y - 4), str(labels[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Ui.MUTED)
		var lw := f.get_string_size(str(labels[-1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(size.x - pad.x - lw, size.y - 4), str(labels[-1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Ui.MUTED)


func _fmt(v: float) -> String:
	return str(roundi(v)) if absf(v) >= 10 else "%.1f" % v
