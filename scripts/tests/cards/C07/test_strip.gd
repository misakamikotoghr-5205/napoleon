# Almanac strip: two suitable actions, one to avoid, a mark on the one already done, text from CardText, inside 196x40.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C07/c07_harness.gd")


func _initialize() -> void:
	var t := T.new(self, "C07_strip")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	await t.frames(1)
	var m := H.mock(bus, "almanac_done")
	var strip: CardAlmanacStrip = load(H.STRIP).instantiate()
	strip.position = Vector2(666, 8)
	root.add_child(strip)
	await t.frames(1)
	strip.refresh(m.view())
	await t.frames(1)
	var yi_a := CardText.ui("g05.almanac.pawn_in")
	var yi_b := CardText.ui("g05.almanac.meet")
	var ji := CardText.ui("g05.almanac.travel")
	t.eq(H.count_text(strip, yi_a), 1, "suitable pawn_in")
	t.eq(H.count_text(strip, yi_b), 1, "suitable meet")
	t.eq(H.count_text(strip, ji), 1, "avoid travel")
	t.eq(H.count_text(strip, CardText.ui("c07.strip.yi")), 1, "yi prefix from CardText")
	t.eq(H.count_text(strip, CardText.ui("c07.strip.ji")), 1, "ji prefix from CardText")
	t.eq(t.all_text_from_cardtext(strip).size(), 0, "strip text is CardText or digits")
	var marked := false
	var extra := false
	for n in H.walk(strip):
		if not (n is Control) or not (n as Control).has_meta("action"):
			continue
		var act := str((n as Control).get_meta("action"))
		var has_mark := (n as Control).get_node_or_null("DoneMark") != null
		if act == "pawn_in":
			marked = has_mark
		elif has_mark:
			extra = true
	for n2 in H.walk(strip):
		if n2 is Label:
			t.ok((n2 as Label).get_theme_font_size("font_size") >= 14, "font at least 14")
	t.ok(marked, "done action has a mark")
	t.ok(not extra, "only the done action is marked")
	t.eq(strip.size, Vector2(196, 40), "strip is 196x40")
	var bounds := strip.get_global_rect().grow(1.0)
	for n in H.walk(strip):
		if n == strip or not (n is Control):
			continue
		var c := n as Control
		if not c.is_visible_in_tree():
			continue
		t.ok(bounds.encloses(c.get_global_rect()), "inside strip: " + str(c.name))
	t.ok(t.anchor_ok(&"a.almanac"), "a.almanac")
	await _overflow(t, strip)
	bus.queue_free()
	strip.queue_free()
	await t.frames(1)


func _overflow(t, strip: CardAlmanacStrip) -> void:
	var actions: Array = []
	for a in CardIds.ALMANAC_ACTIONS:
		actions.append(str(a))
	strip.refresh({"notice": {"almanac": {"id": "alm.shoudang", "yi": actions, "ji": ["travel"], "done": ["travel"]}}})
	await t.frames(1)
	t.ok(H.count_text(strip, "...") >= 1, "ellipsis when the row does not fit")
	var tip: Node = strip._make_custom_tooltip(".")
	for a in actions:
		var word := CardText.ui("g05.almanac." + str(a))
		t.ok(H.count_text(tip, word) >= 1, "tooltip keeps " + str(a))
	t.eq(t.all_text_from_cardtext(tip).size(), 0, "tooltip text is CardText")
	tip.free()
