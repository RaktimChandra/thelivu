## Trial-level telemetry (feature G-01, P-01).
## Every trial is validated against contracts/schemas/telemetry-trial.schema.json
## fields, queued on disk, and uploaded in batches when the network allows.
## Events are idempotent: the server deduplicates by event_id.
extends Node

const QUEUE_PATH := "user://telemetry_queue.jsonl"
const BATCH_SIZE := 200
const REQUIRED := ["event_id", "session_id", "module_id", "module_version", "theme_id", "level",
	"index", "practice", "outcome", "correct", "rt_ms", "t_onset_ms", "recorded_at"]

var session_id := ""
var _http: HTTPRequest
var _sending := false
var _count := 0


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_sent)


func new_session() -> String:
	session_id = _uuid()
	return session_id


## Record one trial. Missing required fields are a programming error in a module.
func record(trial: Dictionary) -> Dictionary:
	trial["event_id"] = _uuid()
	trial["session_id"] = session_id
	trial["recorded_at"] = Time.get_datetime_string_from_system(true) + "Z"
	trial["schema_version"] = AppConfig.SCHEMA_VERSION
	for k in REQUIRED:
		assert(trial.has(k), "Telemetry: trial missing required field '%s'" % k)
	var f := FileAccess.open(QUEUE_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(QUEUE_PATH) else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(JSON.stringify(trial))
	_count += 1
	Bus.trial_recorded.emit(trial)
	return trial


func pending_count() -> int:
	if not FileAccess.file_exists(QUEUE_PATH):
		return 0
	return FileAccess.get_file_as_string(QUEUE_PATH).count("\n")


## Upload queued trials to the API (offline-first; safe to call any time).
func sync(api_base: String, token: String) -> void:
	if _sending or api_base == "" or not FileAccess.file_exists(QUEUE_PATH):
		return
	var lines := FileAccess.get_file_as_string(QUEUE_PATH).split("\n", false)
	if lines.is_empty():
		return
	var batch := []
	for l in lines.slice(0, BATCH_SIZE):
		var parsed: Variant = JSON.parse_string(l)
		if typeof(parsed) == TYPE_DICTIONARY:
			batch.append(parsed)
	_sending = true
	var headers := ["Content-Type: application/json", "Authorization: Bearer " + token]
	var err := _http.request(api_base + "/v1/telemetry/trials:batch", headers, HTTPClient.METHOD_POST,
		JSON.stringify({"trials": batch}))
	if err != OK:
		_sending = false
	else:
		set_meta("sent_n", batch.size())


func _on_sent(_result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_sending = false
	if code < 200 or code >= 300:
		return
	var n: int = get_meta("sent_n", 0)
	var lines := FileAccess.get_file_as_string(QUEUE_PATH).split("\n", false)
	var rest := lines.slice(n)
	var f := FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
	for l in rest:
		f.store_line(l)


static func _uuid() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]
