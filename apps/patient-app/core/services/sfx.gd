## Soft, generated feedback tones. No harsh error sounds (research dossier §7).
## Production replaces these with designed sound assets of the same names.
extends Node

const RATE := 22050.0

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _queue: Array = []  # [{freq, dur, vol, start}]
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.15
	_player = AudioStreamPlayer.new()
	_player.stream = gen
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()


func tone(freq: float, dur := 0.25, vol := 0.18, delay := 0.0) -> void:
	if not bool(Store.settings().get("sound", true)):
		return
	_queue.append({"freq": freq, "dur": dur, "vol": vol, "start": _t + delay})


func good() -> void:
	tone(660.0, 0.22); tone(880.0, 0.30, 0.16, 0.1)

func gentle() -> void:
	tone(392.0, 0.28, 0.12)

func tick() -> void:
	tone(520.0, 0.08, 0.08)

func level_up() -> void:
	tone(784.0, 0.2); tone(1046.5, 0.35, 0.16, 0.1)

func done() -> void:
	tone(523.25, 0.3); tone(659.25, 0.3, 0.16, 0.14); tone(783.99, 0.45, 0.16, 0.28)


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	for i in frames:
		var s := 0.0
		for n in _queue:
			var local: float = _t - n.start
			if local >= 0.0 and local < n.dur:
				var env := minf(local / 0.02, 1.0) * pow(1.0 - local / n.dur, 2.0)
				s += sin(TAU * n.freq * local) * n.vol * env
		_playback.push_frame(Vector2(s, s))
		_t += 1.0 / RATE
	_queue = _queue.filter(func(n): return _t - n.start < n.dur)
