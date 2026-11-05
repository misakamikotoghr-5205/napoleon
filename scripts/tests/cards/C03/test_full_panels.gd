# C03：留牌满的两种结束都恰好丢一次；人脉满 can_close 为假，选了才 release。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C03/harness.gd")
const KEPT := "res://scenes/cards/slots/KeptFull.tscn"
const CONTACTS := "res://scenes/cards/slots/ContactsFull.tscn"


func _initialize() -> void:
	var t := T.new(self, "C03_full_panels")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	H.leaks_all(t)
	await _kept_pick(t)
	await _kept_close(t, "button")
	await _kept_close(t, "esc")
	await _kept_close(t, "host")
	await _kept_pending(t)
	await _contacts(t)


func _kept_pick(t) -> void:
	var pair: Array = H.boot(self, "kept_full")
	var panel := H.open_panel(self, pair[1], pair[0], KEPT, {"new_uid": "c0088"})
	await t.frames(2)
	t.ok(t.anchor_ok(&"a.slots.discard"), "discard anchor")
	var card: CardWidget = panel.find_child("Disc_c0020", true, false)
	card.pressed.emit(card.get_uid())
	await t.frames(1)
	_one_discard(t, pair[1], "c0020", "pick kept")
	H.ui_ok(t, panel)
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_ESCAPE
	panel._unhandled_input(ev)
	panel.queue_free()
	await t.frames(3)
	_one_discard(t, pair[1], "c0020", "pick kept stays one")
	pair[0].queue_free()
	await t.frames(1)


func _kept_close(t, how: String) -> void:
	var pair: Array = H.boot(self, "kept_full")
	var panel := H.open_panel(self, pair[1], pair[0], KEPT, {"new_uid": "c0088"})
	await t.frames(1)
	if how == "button":
		(panel.find_child("CloseBtn", true, false) as Button).pressed.emit()
	elif how == "esc":
		var ev := InputEventKey.new()
		ev.pressed = true
		ev.keycode = KEY_ESCAPE
		panel._unhandled_input(ev)
	else:
		panel.queue_free()
		await t.frames(3)
	if how != "host":
		await t.frames(2)
	_one_discard(t, pair[1], "c0088", "close " + how)
	if is_instance_valid(panel):
		H.ui_ok(t, panel)
		panel.queue_free()
	await t.frames(2)
	pair[0].queue_free()
	await t.frames(1)


func _kept_pending(t) -> void:
	var pair: Array = H.boot(self, "kept_full")
	var panel := H.open_panel(self, pair[1], pair[0], KEPT, {})
	await t.frames(1)
	t.ok(panel.find_child("DiscNew", true, false) != null, "pending supplies new uid")
	var steps: int = await H.drive(self, panel)
	t.ok(steps >= 1, "kept autoplay")
	_one_discard(t, pair[1], "c0088", "autoplay drops new")
	await H.drop(self, [panel, pair[0]])


func _contacts(t) -> void:
	var pair: Array = H.boot(self, "contacts_full")
	var panel := H.open_panel(self, pair[1], pair[0], CONTACTS, {"new_uid": "c0099"}) as CardContactsFull
	await t.frames(2)
	t.ok(t.anchor_ok(&"a.slots.release"), "release anchor")
	t.ok(panel.can_close(), "contacts full can close")
	var card: CardWidget = panel.find_child("Rel_c0012", true, false)
	card.pressed.emit(card.get_uid())
	await t.frames(1)
	t.eq(H.cmds(pair[1], "contact.release"), [{"uid": "c0012"}], "release first contact")
	t.ok(panel.can_close(), "can close after release")
	H.ui_ok(t, panel)
	await H.drop(self, [panel, pair[0]])
	pair = H.boot(self, "contacts_full")
	panel = H.open_panel(self, pair[1], pair[0], CONTACTS, {}) as CardContactsFull
	await t.frames(1)
	t.ok(panel.find_child("NewCard", true, false) != null, "pending contact is the new one")
	var steps: int = await H.drive(self, panel)
	t.ok(steps >= 1, "contacts autoplay")
	t.eq(H.cmds(pair[1], "contact.release"), [{"uid": "c0012"}], "autoplay releases the first")
	await H.drop(self, [panel, pair[0]])
	pair = H.boot(self, "contacts_full")
	panel = H.open_panel(self, pair[1], pair[0], CONTACTS, {"new_uid": "c0099"}) as CardContactsFull
	await t.frames(1)
	var closes := [0]
	panel.close_requested.connect(func(_r: Dictionary) -> void: closes[0] += 1)
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_ESCAPE
	panel._unhandled_input(ev)
	t.eq(closes[0], 1, "esc closes contacts full")
	t.eq(H.cmds(pair[1], "contact.release"), [{"uid": "c0099"}], "esc releases the new contact")
	await H.drop(self, [panel, pair[0]])


func _one_discard(t, mock: MockCardEngine, uid: String, msg: String) -> void:
	var rows: Array = H.cmds(mock, "card.discard")
	t.eq(rows.size(), 1, msg + " count")
	if rows.size() == 1:
		t.eq(str(rows[0]["uid"]), uid, msg + " uid")
