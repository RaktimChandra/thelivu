## Shared recall widget for memory games: a row of answer slots that fill as the
## patient taps items on a pad, with Undo. Emits `submitted` once every slot is filled.
## Items: [{id, text?, icon? (Texture2D)}].
class_name SequenceRecall
extends VBoxContainer

signal submitted(sequence: Array)

var tile_color := Ui.PAPER
var ink := Ui.INK
var columns := 3
var _slots: HBoxContainer
var _pad: GridContainer
var _undo: Button
var _k := 0
var _chosen: Array = []
var _items: Dictionary = {}
var _buttons: Dictionary = {}
var _locked := false


func _init() -> void:
	add_theme_constant_override("separation", Ui.s(16))
	_slots = Ui.hbox(10)
	_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_slots)
	_pad = GridContainer.new()
	_pad.add_theme_constant_override("h_separation", Ui.s(12))
	_pad.add_theme_constant_override("v_separation", Ui.s(12))
	_pad.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(_pad)
	_undo = Ui.button(I18n.t("common.undo"), "ghost", Ui.SIZE_S, 72, "back")
	_undo.pressed.connect(_on_undo)
	add_child(_undo)


func present(items: Array, k: int) -> void:
	_k = k
	_chosen.clear()
	_locked = false
	_items.clear()
	_buttons.clear()
	for c in _pad.get_children():
		c.queue_free()
	_pad.columns = columns
	for it in items:
		_items[it.id] = it
		var b := _tile(it, Ui.s(120))
		b.pressed.connect(_on_pick.bind(it.id))
		_pad.add_child(b)
		_buttons[it.id] = b
	_redraw_slots()


func button_for(id: String) -> Button:
	return _buttons.get(id)


func lock() -> void:
	_locked = true
	for b in _buttons.values():
		b.disabled = true
	_undo.disabled = true


## Colour each slot: true = right, false = wrong (after scoring).
func mark(results: Array) -> void:
	for i in mini(results.size(), _slots.get_child_count()):
		var s: Control = _slots.get_child(i)
		s.add_theme_stylebox_override("normal", Ui.box(Color(Ui.GOOD if results[i] else Ui.SLATE, 0.15), 14, Ui.GOOD if results[i] else Ui.SLATE, 4))
		s.add_theme_stylebox_override("disabled", s.get_theme_stylebox("normal"))


func _on_pick(id: String) -> void:
	if _locked or _chosen.size() >= _k:
		return
	Sfx.tick()
	_chosen.append(id)
	_redraw_slots()
	if _chosen.size() == _k:
		lock()
		submitted.emit(_chosen.duplicate())


func _on_undo() -> void:
	if _locked or _chosen.is_empty():
		return
	_chosen.pop_back()
	_redraw_slots()


func _redraw_slots() -> void:
	for c in _slots.get_children():
		c.queue_free()
	var size := Ui.s(clampi(560 / maxi(1, _k), 64, 96))
	for i in _k:
		var b: Button
		if i < _chosen.size():
			b = _tile(_items[_chosen[i]], size)
		else:
			b = Button.new()
			b.custom_minimum_size = Vector2(size, size)
			b.add_theme_stylebox_override("normal", Ui.box(Color.TRANSPARENT, 14, Ui.LINE, 3))
			b.add_theme_stylebox_override("disabled", Ui.box(Color.TRANSPARENT, 14, Ui.LINE, 3))
		b.disabled = true
		b.focus_mode = FOCUS_NONE
		_slots.add_child(b)
	_undo.disabled = _locked or _chosen.is_empty()


func _tile(it: Dictionary, size: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.size_flags_horizontal = SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("normal", Ui.box(tile_color, 16, Ui.LINE, 2))
	b.add_theme_stylebox_override("hover", Ui.box(tile_color.darkened(0.04), 16, Ui.TEAL, 2))
	b.add_theme_stylebox_override("pressed", Ui.box(Ui.TEAL_SOFT, 16, Ui.TEAL, 3))
	b.add_theme_stylebox_override("disabled", Ui.box(tile_color, 16, Ui.LINE, 2))
	b.add_theme_stylebox_override("focus", Ui.box(Color.TRANSPARENT, 16, Ui.TURMERIC, 4))
	if it.get("icon") != null:
		b.icon = it.icon
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", int(size * 0.62))
	else:
		b.text = str(it.get("text", ""))
		b.add_theme_font_size_override("font_size", int(size * 0.42))
		for st in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
			b.add_theme_color_override(st, ink)
		if Ui.display_font:
			b.add_theme_font_override("font", Ui.display_font)
	return b
