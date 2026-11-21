## Home: today's session at a glance (R2, R3, R13), one big start button,
## the week's sign-in streak and the "not feeling well" button.
extends Screen


func build() -> void:
	var b := page("", false, true)
	var d := Store.day()
	var s := Store.settings()
	b.add_child(Ui.label(I18n.t("home.hello", {"name": App.display_name()}), Ui.SIZE_M, Ui.MUTED))
	b.add_child(Ui.title(I18n.t("home.done_today") if d.complete else I18n.t("home.ready"), Ui.SIZE_XL))

	# Today card -------------------------------------------------------------
	var card := Ui.card(Ui.NIGHT, 30, 28, Color.TRANSPARENT)
	var v := Ui.vbox(18)
	card.add_child(v)
	var row := Ui.hbox(24)
	v.add_child(row)
	var ring := RingProgress.new()
	ring.value = clampf(float(d.minutes) / float(s.complete_min_minutes), 0.0, 1.0)
	ring.caption = "%d" % roundi(float(d.minutes))
	ring.sub = I18n.t("common.min")
	ring.custom_minimum_size = Vector2(Ui.s(190), Ui.s(190))
	row.add_child(ring)
	var info := Ui.vbox(8)
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)
	info.add_child(Ui.label(I18n.t("home.today"), Ui.SIZE_S, Color("a9c6d8"), true))
	info.add_child(Ui.label(I18n.t("home.games_played", {"n": d.games}), Ui.SIZE_M, Color.WHITE))
	var focus := _focus_domain()
	if focus != "":
		info.add_child(Ui.label(I18n.t("home.focus", {"domain": I18n.t("domain.%s.name" % focus)}), Ui.SIZE_S, Color("f6e7c8")))
	var start := Ui.button(I18n.t("home.continue") if d.games > 0 else I18n.t("home.start"), "warm", Ui.SIZE_L, 120)
	start.pressed.connect(App.start_session)
	v.add_child(start)
	v.add_child(Ui.label(I18n.t("home.session_hint", {"min": int(s.session_budget_min)}), Ui.SIZE_XS, Color("a9c6d8"), false, HORIZONTAL_ALIGNMENT_CENTER))
	b.add_child(card)
	start.grab_focus.call_deferred()

	# Week streak --------------------------------------------------------------
	var wk := Ui.card()
	var wv := Ui.vbox(14)
	wk.add_child(wv)
	wv.add_child(Ui.label(I18n.t("home.this_week"), Ui.SIZE_S, Ui.MUTED, true))
	var dots := Ui.hbox(10)
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	wv.add_child(dots)
	var days: Dictionary = Store.get_value("days", {})
	var now := int(Time.get_unix_time_from_system())
	for i in range(6, -1, -1):
		var key := Time.get_date_string_from_unix_time(now - i * 86400)
		var info_d: Dictionary = days.get(key, {})
		var dot := DayDot.new()
		dot.state = "complete" if info_d.get("complete", false) else ("signed_in" if info_d.get("signed_in", false) else "none")
		dot.today = i == 0
		dot.letter = I18n.list("common.weekdays")[Time.get_date_dict_from_unix_time(now - i * 86400).weekday] if I18n.list("common.weekdays").size() == 7 else ""
		dot.custom_minimum_size = Vector2(Ui.s(72), Ui.s(96))
		dots.add_child(dot)
	b.add_child(wk)

	b.add_child(not_well_button("home"))
	if OS.is_debug_build() and not Modules.errors().is_empty():
		b.add_child(Ui.label("Module errors: " + ", ".join(Modules.errors()), Ui.SIZE_XS, Ui.SLATE))


func _focus_domain() -> String:
	var e := App.build_engine()
	return e.weakest_domain()


func on_back() -> void:
	get_tree().quit()
