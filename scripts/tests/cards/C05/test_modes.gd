# C05：六种办法的 card.choose、柜台上的格子、slot.place / slot.remove、demand.submit、铜钱正反。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C05/support.gd")

const MODES: Array = [
	{"file": "money.json", "uid": "m_pay", "choice": "pay", "slot": "cash",
		"drag": {"kind": "money", "amount": 60}, "placed": {"kind": "money", "amount": 60},
		"def": "dm.1938.money.t1", "coins": false, "remove": true, "drop_ok": true},
	{"file": "money.json", "uid": "m_haggle", "choice": "haggle", "slot": "favor",
		"drag": {"kind": "card", "uid": "k1", "zone": "kept"}, "placed": {"kind": "kept", "uid": "k1"},
		"def": "dm.1938.money.t1", "coins": true, "faces": [true, false, true], "need": 2,
		"remove": false, "drop_ok": true},
	{"file": "goods.json", "uid": "g_pay", "choice": "pay", "slot": "goods",
		"drag": {"kind": "item", "item": "I100"}, "placed": {"kind": "item", "item": "I100"},
		"def": "dm.1938.goods.t0", "coins": false, "remove": false, "drop_ok": false},
	{"file": "goods.json", "uid": "g_sub", "choice": "substitute", "slot": "sub",
		"drag": {"kind": "money", "amount": 40}, "placed": {"kind": "money", "amount": 40},
		"def": "dm.1938.goods.t0", "coins": false, "remove": false, "drop_ok": true},
	{"file": "people.json", "uid": "p_send", "choice": "send_person", "slot": "man",
		"drag": {"kind": "self"}, "placed": {"kind": "self"},
		"def": "dm.1938.people.t2", "coins": false, "remove": false, "drop_ok": false, "away": true},
	{"file": "info.json", "uid": "i_inform", "choice": "inform", "slot": "news",
		"drag": {"kind": "card", "uid": "n1", "zone": "hand"}, "placed": {"kind": "news", "uid": "n1"},
		"def": "dm.1938.info.t3", "coins": false, "remove": false, "drop_ok": true},
	{"file": "info.json", "uid": "i_fab", "choice": "fabricate", "slot": "nerve",
		"drag": {"kind": "self"}, "placed": {"kind": "self"},
		"def": "dm.1938.info.t3", "coins": true, "faces": [true, false], "need": 2,
		"remove": false, "drop_ok": false},
]


func _initialize() -> void:
	var t := T.new(self, "C05_modes")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	for spec in MODES:
		await _one(t, spec)


func _one(t, spec: Dictionary) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var spy = t.spy(bus)
	var eng := S.engine(bus, str(spec["file"]))
	var uid := str(spec["uid"])
	var panel := S.mount_panel(self, eng, bus, uid)
	await t.frames(1)
	S.skip_dialog(panel)
	await t.frames(1)
	var choice := str(spec["choice"])
	var btn := S.reply_button(panel, "c05.mode." + choice)
	t.ok(btn != null, "reply " + choice)
	btn.pressed.emit()
	t.ok(S.sent_has(eng, "card.choose", {"uid": uid, "choice": choice}), "choose " + choice)
	var slot := str(spec["slot"])
	var widget := S.slot_widget(panel, slot)
	t.ok(widget != null, "widget " + slot)
	var drag: Dictionary = spec["drag"]
	var expect_drop := bool(spec["drop_ok"])
	if widget.has_method("accepts_kind") and widget.accepts_kind(str(spec["placed"].get("kind", ""))):
		expect_drop = true
	t.eq(widget._can_drop_data(Vector2.ZERO, drag), expect_drop, "can drop " + choice)
	widget._drop_data(Vector2.ZERO, drag)
	t.ok(S.sent_place(eng, uid, slot, spec["placed"]), "place " + choice)
	var saw := false
	for ev in spy.ui_events():
		if ev[0] == &"slot_drop" and str(ev[1]["slot"]) == slot:
			saw = true
	t.ok(saw, "slot_drop " + choice)
	if bool(spec.get("remove", false)):
		widget.remove_requested.emit(slot, 0)
		t.ok(S.sent_has(eng, "slot.remove", {"uid": uid, "slot": slot, "index": 0}), "remove")
	await t.frames(1)
	if bool(spec.get("away", false)):
		t.eq((panel.find_child("Away", true, false) as Label).text, "7", "away days")
	var seen := {"faces": []}
	bus.coins_tossed.connect(func(_u: String, faces: Array, _n: int, _ok: bool) -> void:
		seen["faces"] = faces.duplicate())
	var submit := S.reply_button(panel, "c05.reply.submit")
	t.ok(submit != null, "submit reply")
	submit.pressed.emit()
	t.ok(S.sent_has(eng, "demand.submit", {"uid": uid}), "submit " + choice)
	var toss_now := panel.find_child("CoinToss", true, false) as CardCoinTossView
	if toss_now != null and toss_now._playing:
		toss_now.skip()
	await t.frames(2)
	if bool(spec["coins"]):
		var toss := panel.find_child("CoinToss", true, false) as CardCoinTossView
		t.ok(toss != null, "toss view " + choice)
		if toss != null:
			t.eq(toss._faces, spec["faces"], "faces " + choice)
			t.eq(toss._need, int(spec["need"]), "need " + choice)
		t.eq(panel._coin_faces, spec["faces"], "passed faces " + choice)
		t.eq(panel._coin_need, int(spec["need"]), "passed need " + choice)
		t.eq(seen["faces"], spec["faces"], "event faces " + choice)
	t.eq(S.dialog_line(panel), CardText.card(str(spec["def"]), "outcomes.success"), "outcome " + choice)
	var shown: PackedStringArray = t.all_text_from_cardtext(panel)
	t.ok(shown.is_empty(), "text " + " | ".join(shown))
	var pct := S.percent_text(panel)
	t.ok(pct.is_empty(), "percent " + " | ".join(pct))
	panel.queue_free()
	bus.queue_free()
	await t.frames(1)
