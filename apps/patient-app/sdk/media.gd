## Media lookup shared by the shell and every module.
## Photographs win over drawings: for a base path it tries .webp, .png, .jpg, then .svg.
## Every photo must be listed in res://assets/media/manifest.json with its source,
## licence, consent basis and validation status (see docs/research/THL-RES-002).
class_name Media
extends RefCounted

const PHOTO_EXT := ["webp", "png", "jpg"]
const ALL_EXT := ["webp", "png", "jpg", "svg"]
const MANIFEST := "res://assets/media/manifest.json"

static var _manifest: Dictionary = {}
static var _loaded := false


static func load_texture(base: String) -> Texture2D:
	for ext in ALL_EXT:
		var p := "%s.%s" % [base, ext]
		if ResourceLoader.exists(p):
			return load(p)
	return null


static func is_photo(base: String) -> bool:
	for ext in PHOTO_EXT:
		if ResourceLoader.exists("%s.%s" % [base, ext]):
			return true
	return false


## Manifest entry for an asset id, e.g. "hands/point". Empty if not listed.
static func info(asset_id: String) -> Dictionary:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(MANIFEST):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
			if typeof(d) == TYPE_DICTIONARY:
				for a in d.get("assets", []):
					_manifest[a.id] = a
	return _manifest.get(asset_id, {})


## Only assets the clinical team has approved may be shown to patients.
static func approved(asset_id: String) -> bool:
	return str(info(asset_id).get("status", "")) == "approved"
