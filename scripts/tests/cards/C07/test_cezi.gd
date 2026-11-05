# Character reading: the mat shows one card per id, the second pick is sent, the hint comes from CardText.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C07/c07_harness.gd")


func _initialize() -> void:
	var t := T.new(self, "C07_cezi")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	await t.frames(1)
	var m := H.mock(bus, "cezi_only")
	var panel: CardFortunePanel = load(H.PANEL).instantiate()
	panel.bind(m, bus)
	root.add_child(panel)
	panel.open({"uid": H.UID})
	await t.frames(1)
	var portrait := _portrait(panel)
	t.ok(portrait != null and str(portrait.get_meta("art_id")) == "icon.obj.notice", "stall uses the card art")
	var offer: Array = m.query(&"fortune", {"uid": H.UID}).get("cezi", [])
	H.button_by_key(panel, "c07.btn.cezi").pressed.emit()
	var buttons := H.char_buttons(panel)
	t.eq(buttons.size(), offer.size(), "one tile per character")
	t.ok(t.anchor_ok(&"a.fortune.chars"), "a.fortune.chars")
	for i in range(buttons.size()):
		var b: Button = buttons[i]
		var cid := str(b.get_meta("char_id"))
		t.eq(cid, str(offer[i]), "tile order")
		t.eq(b.text, CardText.card(cid, "char"), "character from CardText")
	var second := str(offer[1])
	buttons[1].pressed.emit()
	var rows: Array = H.sent(m, "fortune.cezi")
	t.eq(rows.size(), 1, "one fortune.cezi")
	t.eq(rows[0], {"uid": H.UID, "char": second}, "second character is sent")
	var hint := CardText.card(second, "none")
	t.ok(H.count_text(panel, hint) >= 1, "hint from CardText.card(char, reading)")
	t.eq(t.all_text_from_cardtext(panel).size(), 0, "panel text is CardText or digits")
	panel.queue_free()
	bus.queue_free()
	await t.frames(1)


func _portrait(panel: Node) -> TextureRect:
	for n in H.walk(panel):
		if n is TextureRect and (n as TextureRect).has_meta("art_id"):
			return n
	return null
