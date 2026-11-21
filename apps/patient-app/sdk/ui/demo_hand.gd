## The "hand" in instruction demos. Uses a real photograph of a pointing hand
## (res://assets/media/hands/point.*) when one is approved in the media manifest;
## otherwise a soft touch marker. It glides to a target and ripples on tap.
class_name DemoHand
extends Control

const PHOTO := "res://assets/media/hands/point"
## Fingertip position inside the photo, as a fraction of its size.
const TIP := Vector2(0.42, 0.04)

var _ripple := 0.0
var _pos := Vector2(-200, -200)
var _photo: Texture2D


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	Ui.fill(self)
	z_index = 10
	if Media.is_photo(PHOTO) and Media.approved("hands/point"):
		_photo = Media.load_texture(PHOTO)


func move_to(dest: Vector2, dur: float, on_arrive: Callable) -> void:
	if _pos.x < -100:
		_pos = Vector2(size.x * 0.6, size.y + 60)
	var tw := create_tween()
	tw.tween_method(_set_pos, _pos, dest, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		_ripple = 0.001
		on_arrive.call())
	tw.tween_method(func(v): _ripple = v; queue_redraw(), 0.001, 1.0, 0.45)
	tw.tween_callback(func(): _ripple = 0.0; queue_redraw())


func _set_pos(v: Vector2) -> void:
	_pos = v
	queue_redraw()


func _draw() -> void:
	var r := float(Ui.s(30))
	if _ripple > 0.0:
		draw_arc(_pos, r + _ripple * r * 1.6, 0, TAU, 48, Color(Ui.TURMERIC, 1.0 - _ripple), 5, true)
	if _photo:
		var h := float(Ui.s(220))
		var w := h * _photo.get_width() / maxf(1.0, _photo.get_height())
		var press := 0.06 if _ripple > 0.0 and _ripple < 0.4 else 0.0
		var sz := Vector2(w, h) * (1.0 - press)
		draw_texture_rect(_photo, Rect2(_pos - sz * TIP, sz), false)
		return
	draw_circle(_pos + Vector2(3, 5), r, Color(0, 0, 0, 0.12))
	draw_circle(_pos, r, Color(Ui.TURMERIC, 0.85))
	draw_arc(_pos, r, 0, TAU, 48, Color.WHITE, 4, true)
