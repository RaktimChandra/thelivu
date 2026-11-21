## A theme pack changes what a game *looks like*, never what the brain must do
## (research dossier §6). It holds labels, colours and image assets only;
## timings, counts and difficulty stay in the module's level table.
class_name ThemePack
extends RefCounted

var id := ""
var dir := ""
var data: Dictionary = {}
var _cache := {}


static func load_from(path: String, theme_id: String) -> ThemePack:
	var p := ThemePack.new()
	p.id = theme_id
	p.dir = path
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + "/theme.json"))
	p.data = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return p


func get_value(key: String, default: Variant = null) -> Variant:
	return data.get(key, default)


## Localised string from the theme ({"en": "...", "ta": "...", "hi": "..."} or a plain string).
func text(key: String) -> String:
	var v: Variant = data.get(key, key)
	if typeof(v) == TYPE_DICTIONARY:
		return str(v.get(I18n.lang, v.get("en", key)))
	return str(v)


func localized(v: Variant) -> String:
	if typeof(v) == TYPE_DICTIONARY:
		return str(v.get(I18n.lang, v.get("en", "")))
	return str(v)


## Texture from the pack's assets folder (cached). Real photographs (webp, png,
## jpg) take priority over vector drawings, so a pack can be upgraded to real
## human faces, hands or objects by dropping photos next to the SVGs.
func texture(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var tex := Media.load_texture("%s/assets/%s" % [dir, name])
	_cache[name] = tex
	return tex
