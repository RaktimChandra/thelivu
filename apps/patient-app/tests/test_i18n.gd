## Every key used by the app exists in every language, and every module ships all three languages.
extends Node


func test_locale_parity(t) -> void:
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://locales/en.json"))
	for code in ["ta", "hi"]:
		var other: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://locales/%s.json" % code))
		for k in en:
			t.check(other.has(k), "%s missing key %s" % [code, k])


func test_module_strings(t) -> void:
	for m in Modules.all():
		for code in ["en", "ta", "hi"]:
			var path: String = "%s/i18n/%s.json" % [m.dir, code]
			t.check(FileAccess.file_exists(path), "%s missing %s" % [m.id, path])
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			for k in ["name", "goal", "tip", "voice"]:
				t.check(typeof(d) == TYPE_DICTIONARY and d.has(k), "%s/%s missing '%s'" % [m.id, code, k])


func test_placeholders(t) -> void:
	I18n.set_language("ta")
	t.check(I18n.t("library.level", {"n": 3, "max": 10}).contains("3"), "placeholder replaced in Tamil")
	I18n.set_language("en")
	t.eq(I18n.t("no.such.key"), "no.such.key", "missing key returns key")
