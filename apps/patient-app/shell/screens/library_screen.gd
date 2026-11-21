## Activity library: all seven domains. Domains without modules show as
## "coming soon" so the structure of the full programme is visible from day one.
extends Screen


func build() -> void:
	var b := page(I18n.t("nav.activities"), false, true)
	for domain in AppConfig.DOMAINS:
		var mods := Modules.by_domain(domain, true)
		var card := Ui.card(Ui.PAPER if not mods.is_empty() else Ui.MIST)
		var v := Ui.vbox(12)
		card.add_child(v)
		var head := Ui.hbox(14)
		v.add_child(head)
		var badge := Ui.label(str(AppConfig.DOMAINS.find(domain) + 1), Ui.SIZE_S, Color.WHITE if not mods.is_empty() else Ui.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER, false)
		badge.custom_minimum_size = Vector2(Ui.s(52), Ui.s(52))
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_stylebox_override("normal", Ui.box(Ui.TEAL if not mods.is_empty() else Ui.LINE, 26))
		head.add_child(badge)
		var tv := Ui.vbox(2)
		tv.size_flags_horizontal = SIZE_EXPAND_FILL
		head.add_child(tv)
		tv.add_child(Ui.label(I18n.t("domain.%s.name" % domain), Ui.SIZE_M, Ui.INK, true))
		tv.add_child(Ui.label(I18n.t("domain.%s.everyday" % domain), Ui.SIZE_XS, Ui.MUTED))
		if mods.is_empty():
			v.add_child(Ui.label(I18n.t("library.coming_soon"), Ui.SIZE_S, Ui.MUTED))
		for m in mods:
			v.add_child(_module_row(m))
		b.add_child(card)


func _module_row(m: Dictionary) -> Control:
	var btn := Button.new()
	btn.flat = false
	btn.custom_minimum_size.y = Ui.s(104)
	btn.add_theme_stylebox_override("normal", Ui.box(Ui.TEAL_SOFT if m.get("status", "official") == "official" else Ui.TURMERIC_SOFT, 18))
	btn.add_theme_stylebox_override("hover", Ui.box((Ui.TEAL_SOFT if m.get("status", "official") == "official" else Ui.TURMERIC_SOFT).darkened(0.04), 18))
	btn.add_theme_stylebox_override("pressed", Ui.box((Ui.TEAL_SOFT if m.get("status", "official") == "official" else Ui.TURMERIC_SOFT).darkened(0.08), 18))
	btn.add_theme_stylebox_override("focus", Ui.box(Color.TRANSPARENT, 18, Ui.TURMERIC, 4))
	var h := Ui.hbox(14)
	h.mouse_filter = MOUSE_FILTER_IGNORE
	Ui.fill(h)
	h.offset_left = Ui.s(22)
	h.offset_right = -Ui.s(22)
	btn.add_child(h)
	var ic := TextureRect.new()
	ic.texture = load("%s/icon.svg" % m.dir) if ResourceLoader.exists("%s/icon.svg" % m.dir) else null
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(Ui.s(64), Ui.s(64))
	ic.mouse_filter = MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var tv := Ui.vbox(0)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.size_flags_horizontal = SIZE_EXPAND_FILL
	tv.mouse_filter = MOUSE_FILTER_IGNORE
	h.add_child(tv)
	var name_l := Ui.label(I18n.t("%s.name" % m.id), Ui.SIZE_M, Ui.INK, true)
	name_l.mouse_filter = MOUSE_FILTER_IGNORE
	tv.add_child(name_l)
	var lv := App.module_level(m.id)
	var sub := I18n.t("library.level", {"n": lv, "max": Modules.levels(m.id).size()})
	if m.get("status", "official") != "official":
		sub += " · " + I18n.t("library.alternative")
	var sub_l := Ui.label(sub, Ui.SIZE_XS, Ui.MUTED)
	sub_l.mouse_filter = MOUSE_FILTER_IGNORE
	tv.add_child(sub_l)
	var id: String = m.id
	btn.pressed.connect(func(): App.go("game", {"module_id": id, "session": false}))
	return btn
