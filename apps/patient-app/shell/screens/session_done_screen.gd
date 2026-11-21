## End of today's session.
extends Screen


func build() -> void:
	var b := page()
	b.add_child(Ui.spacer(false, Ui.s(80)))
	var ring := RingProgress.new()
	ring.value = 1.0
	ring.check = true
	ring.track = Ui.TEAL_SOFT
	ring.fill_color = Ui.TEAL
	ring.text_color = Ui.TEAL_DARK
	ring.custom_minimum_size = Vector2(0, Ui.s(300))
	b.add_child(ring)
	b.add_child(Ui.title(I18n.t("done.title"), Ui.SIZE_XL, Ui.INK, HORIZONTAL_ALIGNMENT_CENTER))
	b.add_child(Ui.label(I18n.t("done.summary", {"games": params.get("games", 0), "min": roundi(float(params.get("minutes", 0.0)))}), Ui.SIZE_M, Ui.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	b.add_child(Ui.label(I18n.t("done.bridge"), Ui.SIZE_M, Ui.INK, false, HORIZONTAL_ALIGNMENT_CENTER))
	var home := Ui.button(I18n.t("done.home"), "primary", Ui.SIZE_L, 120)
	home.pressed.connect(func(): App.go("home"))
	b.add_child(home)
	home.grab_focus.call_deferred()
