## Voice-over for instructions (startup requirement R14).
## Order of preference: a recorded native voice file shipped with the module
## (i18n/voice/<lang>/<clip>.ogg), then the platform text-to-speech voice.
extends Node

var _player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	add_child(_player)


func speak(lines: PackedStringArray, module_dir := "", clip := "") -> void:
	stop()
	if not bool(Store.settings().get("voice", true)):
		return
	if module_dir != "" and clip != "":
		var path := "%s/i18n/voice/%s/%s.ogg" % [module_dir, I18n.lang, clip]
		if ResourceLoader.exists(path):
			_player.stream = load(path)
			_player.play()
			return
	var voices := DisplayServer.tts_get_voices_for_language(I18n.lang)
	if voices.is_empty():
		return
	DisplayServer.tts_speak(" ".join(lines), voices[0], 60, 1.0, 0.9)


func stop() -> void:
	if _player.playing:
		_player.stop()
	if DisplayServer.tts_is_speaking():
		DisplayServer.tts_stop()


func available() -> bool:
	return not DisplayServer.tts_get_voices_for_language(I18n.lang).is_empty()
