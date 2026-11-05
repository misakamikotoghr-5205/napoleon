# Draw a lot: fortune.lot is sent, verse and gloss come from CardText, the grade is a word,
# skipping the shake still shows the result, and a short purse shows the reason. Pass sends card.choose.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C07/c07_harness.gd")
const NAMES: Array[String] = ["teller_both", "lot_only", "cezi_only", "after_lot", "no_money", "almanac_done"]


func _initialize() -> void:
	var t := T.new(self, "C07_lot")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	await t.frames(1)
	await _draw(t, bus)
	await _skip(t, bus)
	await _broke(t, bus)
	await _pass(t, bus)
	await _keys(t, bus)
	await _leave(t, bus)
	await _autoplay_all(t, bus)
	await _offered_only(t, bus)
	bus.queue_free()
	await t.frames(1)


func _open(t, bus: CardEventBus, name: String) -> Array:
	var m := H.mock(bus, name)
	var panel: CardFortunePanel = load(H.PANEL).instantiate()
	panel.bind(m, bus)
	root.add_child(panel)
	panel.open({"uid": H.UID})
	await t.frames(1)
	return [m, panel]


func _draw(t, bus: CardEventBus) -> void:
	var pair: Array = await _open(t, bus, "lot_only")
	var m: MockCardEngine = pair[0]
	var panel: CardFortunePanel = pair[1]
	var portrait := _portrait(panel)
	t.ok(portrait != null and str(portrait.get_meta("art_id")) == "portrait.suanming", "fortune teller portrait")
	panel.fast_anim = true
	H.button_by_key(panel, "c07.btn.lot").pressed.emit()
	var rows: Array = H.sent(m, "fortune.lot")
	t.eq(rows.size(), 1, "one fortune.lot")
	t.eq(rows[0], {"uid": H.UID}, "fortune.lot args")
	var lot := "lot.g1.official"
	var verse := CardText.card(lot, "verse")
	var gloss := CardText.card(lot, "gloss")
	var grade := CardText.ui("c07.grade.1")
	t.ok(H.count_text(panel, verse) >= 1, "verse from CardText")
	t.ok(H.count_text(panel, gloss) >= 1, "gloss from CardText")
	if verse == gloss:
		t.ok(H.count_text(panel, verse) >= 2, "verse and gloss are both on screen")
	t.eq(H.count_text(panel, grade), 1, "grade word")
	t.ok(grade != "1" and not grade.is_valid_int(), "grade is not a number")
	panel.queue_free()
	await t.frames(1)


func _skip(t, bus: CardEventBus) -> void:
	var pair: Array = await _open(t, bus, "lot_only")
	var m: MockCardEngine = pair[0]
	var panel: CardFortunePanel = pair[1]
	panel.fast_anim = false
	H.button_by_key(panel, "c07.btn.lot").pressed.emit()
	t.eq(H.sent(m, "fortune.lot").size(), 0, "shake has not sent yet")
	panel._input(H.key_event(KEY_SPACE))
	t.eq(H.sent(m, "fortune.lot").size(), 1, "skip still sends fortune.lot")
	t.ok(H.count_text(panel, CardText.card("lot.g1.official", "verse")) >= 1, "skip keeps the verse")
	t.ok(H.count_text(panel, CardText.ui("c07.grade.1")) == 1, "skip keeps the grade word")
	panel.queue_free()
	await t.frames(1)


func _broke(t, bus: CardEventBus) -> void:
	var pair: Array = await _open(t, bus, "no_money")
	var panel: CardFortunePanel = pair[1]
	panel.fast_anim = true
	H.button_by_key(panel, "c07.btn.lot").pressed.emit()
	var reason := CardText.ui("c07.err.money")
	t.ok(H.count_text(panel, reason) >= 1, "short purse shows the reason")
	t.eq(H.count_text(panel, CardText.card("lot.g1.official", "verse")), 0, "no slip when the fee fails")
	panel.queue_free()
	await t.frames(1)


func _pass(t, bus: CardEventBus) -> void:
	var pair: Array = await _open(t, bus, "almanac_done")
	var m: MockCardEngine = pair[0]
	var panel: CardFortunePanel = pair[1]
	var closed := {"n": 0}
	panel.close_requested.connect(func(_r: Dictionary) -> void: closed["n"] = int(closed["n"]) + 1)
	H.button_by_key(panel, "c07.btn.pass").pressed.emit()
	t.eq(H.sent(m, "card.choose"), [{"uid": H.UID, "choice": "pass"}], "pass sends card.choose")
	t.eq(int(closed["n"]), 1, "pass closes the panel")
	panel.queue_free()
	await t.frames(1)


func _keys(t, bus: CardEventBus) -> void:
	var pair: Array = await _open(t, bus, "teller_both")
	var panel: CardFortunePanel = pair[1]
	var lot_b := H.button_by_key(panel, "c07.btn.lot")
	var cezi_b := H.button_by_key(panel, "c07.btn.cezi")
	t.eq(lot_b.focus_mode, Control.FOCUS_ALL, "lot button can take focus")
	t.eq(cezi_b.focus_mode, Control.FOCUS_ALL, "cezi button can take focus")
	panel._unhandled_input(H.key_event(KEY_TAB))
	t.eq(panel.get_viewport().gui_get_focus_owner(), cezi_b, "Tab moves to the character reading")
	panel._unhandled_input(H.key_event(KEY_ENTER))
	t.eq(H.char_buttons(panel).size(), 3, "Enter opens the characters")
	panel.queue_free()
	await t.frames(1)


func _leave(t, bus: CardEventBus) -> void:
	var pair: Array = await _open(t, bus, "lot_only")
	var panel: CardFortunePanel = pair[1]
	var closed := {"n": 0}
	panel.close_requested.connect(func(_r: Dictionary) -> void: closed["n"] = int(closed["n"]) + 1)
	bus.card_left.emit(H.UID, &"resolved")
	t.eq(int(closed["n"]), 0, "a resolved card keeps the reading open")
	bus.card_left.emit(H.UID, &"left")
	t.eq(int(closed["n"]), 1, "the card leaving closes the stall")
	panel.queue_free()
	await t.frames(1)


func _autoplay_all(t, bus: CardEventBus) -> void:
	for name in NAMES:
		var pair: Array = await _open(t, bus, name)
		var panel: CardFortunePanel = pair[1]
		panel.fast_anim = false
		var steps := 0
		while panel.autoplay_step():
			steps += 1
			if steps > 8:
				break
			await t.frames(1)
		t.ok(steps >= 1 and steps <= 8, "autoplay finishes " + name + " in " + str(steps))
		t.ok(not panel.autoplay_step(), "autoplay stops " + name)
		panel.queue_free()
		await t.frames(1)


func _portrait(panel: Node) -> TextureRect:
	for n in H.walk(panel):
		if n is TextureRect and (n as TextureRect).has_meta("art_id"):
			return n
	return null


## b48: a stall shows only the actions it offers. The temple lot stall has no character reading, so
## "cezi" is hidden (it used to sit there disabled with no reason); the shown buttons do not overlap.
func _offered_only(t, bus: CardEventBus) -> void:
	for row in [["lot_only", true, false], ["cezi_only", false, true], ["teller_both", true, true]]:
		var pair := await _open(t, bus, str(row[0]))
		var panel: CardFortunePanel = pair[1]
		var lot := H.button_by_key(panel, "c07.btn.lot")
		var cezi := H.button_by_key(panel, "c07.btn.cezi")
		var leave := H.button_by_key(panel, "c07.btn.pass")
		t.eq(lot.visible, bool(row[1]), "%s lot shown" % row[0])
		t.eq(cezi.visible, bool(row[2]), "%s cezi shown" % row[0])
		t.ok(leave.visible and not leave.disabled, "%s pass shown" % row[0])
		var shown: Array = []
		for b in [lot, cezi, leave]:
			if b.visible:
				t.ok(not b.disabled, "%s shown button is live" % row[0])
				for other in shown:
					t.ok(not (other as Control).get_global_rect().intersects(b.get_global_rect()), "%s buttons apart" % row[0])
				shown.append(b)
		panel.queue_free()
		await t.frames(1)
