## Progress for the patient (R10, R11, R13): minutes per day, per-game level and
## typical time. Framed against the person's own past, never against others.
extends Screen


func build() -> void:
	var b := page(I18n.t("nav.progress"), false, true)
	var days: Dictionary = Store.get_value("days", {})
	var now := int(Time.get_unix_time_from_system())
	var vals := []
	var labels := []
	for i in range(13, -1, -1):
		var key := Time.get_date_string_from_unix_time(now - i * 86400)
		var dd: Dictionary = days.get(key, {})
		vals.append(float(dd.get("minutes", 0.0)))
		labels.append(key.substr(8, 2) + "/" + key.substr(5, 2))
	var c1 := Ui.card()
	var v1 := Ui.vbox(10)
	c1.add_child(v1)
	v1.add_child(Ui.label(I18n.t("progress.minutes_14"), Ui.SIZE_M, Ui.INK, true))
	var ch := LineChart.new()
	ch.values = vals
	ch.labels = labels
	ch.unit = " " + I18n.t("common.min")
	ch.custom_minimum_size.y = Ui.s(260)
	v1.add_child(ch)
	b.add_child(c1)

	var wk := Store.week_domain_minutes()
	var c2 := Ui.card()
	var v2 := Ui.vbox(12)
	c2.add_child(v2)
	v2.add_child(Ui.label(I18n.t("progress.week_domains"), Ui.SIZE_M, Ui.INK, true))
	var maxm := 1.0
	for d in AppConfig.DOMAINS:
		maxm = maxf(maxm, float(wk.get(d, 0.0)))
	for d in AppConfig.DOMAINS:
		var row := Ui.hbox(12)
		var l := Ui.label(I18n.t("domain.%s.short" % d), Ui.SIZE_XS, Ui.MUTED, false, HORIZONTAL_ALIGNMENT_LEFT, false)
		l.custom_minimum_size.x = Ui.s(190)
		row.add_child(l)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = maxm
		bar.value = float(wk.get(d, 0.0))
		bar.size_flags_horizontal = SIZE_EXPAND_FILL
		bar.size_flags_vertical = SIZE_SHRINK_CENTER
		bar.custom_minimum_size.y = Ui.s(18)
		row.add_child(bar)
		var n := Ui.label("%d" % roundi(float(wk.get(d, 0.0))), Ui.SIZE_XS, Ui.INK, true, HORIZONTAL_ALIGNMENT_RIGHT, false)
		n.custom_minimum_size.x = Ui.s(48)
		row.add_child(n)
		v2.add_child(row)
	b.add_child(c2)

	for m in Modules.all():
		var st := Store.module_state(m.id)
		if int(st.plays) == 0:
			continue
		var lr: Dictionary = st.last_result
		var c := Ui.card()
		var v := Ui.vbox(6)
		c.add_child(v)
		v.add_child(Ui.label(I18n.t("%s.name" % m.id), Ui.SIZE_M, Ui.INK, true))
		v.add_child(Ui.label(I18n.t("progress.module_line", {
			"level": App.module_level(m.id), "max": Modules.levels(m.id).size(),
			"acc": roundi(float(lr.get("accuracy", 0.0)) * 100.0),
			"time": "%.1f" % (float(lr.get("rt_median_ms", 0)) / 1000.0),
			"plays": st.plays}), Ui.SIZE_S, Ui.MUTED))
		b.add_child(c)
	if Modules.all().all(func(m): return int(Store.module_state(m.id).plays) == 0):
		b.add_child(Ui.label(I18n.t("progress.empty"), Ui.SIZE_M, Ui.MUTED))
