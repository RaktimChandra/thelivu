## App shell: background, safe-area margins, animated screen transitions and the
## Android back button. Screens are plain scripts registered in SCREENS.
extends Control

const SCREENS := {
	"language": preload("res://shell/screens/language_screen.gd"),
	"signin": preload("res://shell/screens/signin_screen.gd"),
	"home": preload("res://shell/screens/home_screen.gd"),
	"library": preload("res://shell/screens/library_screen.gd"),
	"progress": preload("res://shell/screens/progress_screen.gd"),
	"settings": preload("res://shell/screens/settings_screen.gd"),
	"game": preload("res://shell/screens/game_screen.gd"),
	"rest": preload("res://shell/screens/rest_screen.gd"),
	"session_done": preload("res://shell/screens/session_done_screen.gd"),
	"safety": preload("res://shell/screens/safety_screen.gd"),
}

var _holder: Control
var _current: Screen


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Ui.MIST
	Ui.fill(bg)
	add_child(bg)
	_holder = Control.new()
	Ui.fill(_holder)
	add_child(_holder)
	_apply_safe_area()
	get_tree().root.size_changed.connect(_apply_safe_area)
	Bus.navigate.connect(_show)
	Bus.safety_requested.connect(func(ctx): _show("safety", {"context": ctx}))
	_show_initial.call_deferred()


## Deep links for demos and visual QA (web build): #screen=home&lang=ta,
## #game=d1_clerical_scan (instructions), #play=d1_clerical_scan&level=6.
func _show_initial() -> void:
	var q := {}
	if OS.has_feature("web"):
		var h := str(JavaScriptBridge.eval("location.hash.replace('#','')", true))
		for part in h.split("&", false):
			var kv := part.split("=")
			q[kv[0]] = kv[1] if kv.size() > 1 else ""
	if q.is_empty():
		_show(App.first_screen(), {})
		return
	App.prepare_demo_profile(str(q.get("lang", "en")))
	if q.has("game"):
		_show("game", {"module_id": q.game, "session": false})
	elif q.has("play"):
		if q.has("level"):
			Store.module_state(q.play)["level"] = int(q.level)
		_show("game", {"module_id": q.play, "session": false, "autostart": true})
	elif q.has("screen") and SCREENS.has(q.screen):
		_show(q.screen, {})
	else:
		_show(App.first_screen(), {})


func _show(name: String, params: Dictionary) -> void:
	if not SCREENS.has(name):
		push_error("Unknown screen %s" % name)
		return
	get_tree().paused = false
	Voice.stop()
	var next: Screen = SCREENS[name].new()
	next.screen_name = name
	next.params = params
	Ui.fill(next)
	next.modulate.a = 0.0
	_holder.add_child(next)
	next.build()
	var old := _current
	_current = next
	var tw := create_tween().set_parallel(true)
	tw.tween_property(next, "modulate:a", 1.0, 0.22)
	next.position.y = 24
	tw.tween_property(next, "position:y", 0.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if old:
		old.leave()
		var t2 := create_tween()
		t2.tween_property(old, "modulate:a", 0.0, 0.12)
		t2.tween_callback(old.queue_free)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _current:
		_current.on_back()


func _apply_safe_area() -> void:
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var vp := get_viewport_rect().size
	if win.x <= 0 or safe.size.x <= 0 or OS.has_feature("web") or OS.has_feature("pc"):
		_holder.offset_top = 0
		_holder.offset_bottom = 0
		return
	var k := vp.y / float(win.y)
	_holder.offset_top = maxf(0.0, safe.position.y * k)
	_holder.offset_bottom = -maxf(0.0, (win.y - safe.end.y) * k)
