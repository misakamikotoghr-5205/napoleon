# 五个指引步骤会亮、会完成；四个轮盘锚点在 1280x720 里。主人 C06。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C06/support.gd")
const STEPS := "res://scripts/tests/cards/C06/guide_steps.json"


func _initialize() -> void:
	var t := T.new(self, _arg("--name=", "C06_guide"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	if _arg("--steps=", "") == "k16":
		await _k16(t)
		return
	var k16 := _arg("--steps=", "") == "k16"
	var pack := S.boot(self)
	var mock: MockCardEngine = pack["mock"]
	var bus: CardEventBus = pack["bus"]
	mock.load_fixture(S.FIX + "month_widen.json")
	var panel := S.open_panel(self, mock, bus, S.args_of(S.read_fix("month_widen")))
	await t.frames(2)
	for id in ["a.wheel.face", "a.wheel.incense", "a.wheel.cost", "a.wheel.spin"]:
		t.ok(t.anchor_ok(StringName(id)), "anchor %s rect %s" % [id, str(CardAnchors.rect(StringName(id)))])
	var data = CardDB.read_json(STEPS)
	var guide := _guide(bus, mock, data, k16)
	bus.first_time.emit(&"month_wheel", {})
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.m.wheel", "month wheel step lights")
	guide.tick(1.0)
	t.eq(guide.active_step(), "", "month wheel step completes")
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.m.incense", "incense step lights next")
	var slot := panel.find_child("IncenseSlot", true, false) as CardSlotWidget
	slot._drop_data(Vector2.ZERO, {"kind": "money", "amount": 10})
	t.eq(guide.active_step(), "", "dropping incense completes the step")
	var card := ColorRect.new()
	card.color = CardTheme.color(&"paper")
	card.position = Vector2(24, 24)
	card.size = Vector2(96, 120)
	root.add_child(card)
	CardAnchors.register(&"a.card@c0099", card)
	await t.frames(1)
	bus.first_time.emit(&"big_wheel", {"uid": "c0099"})
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.big_wheel", "big wheel step lights on the card")
	guide.tick(1.0)
	guide.evaluate_now()
	bus.first_time.emit(&"fair_wheel", {})
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.fair_wheel", "fair step lights on the cost")
	guide.tick(1.0)
	guide.evaluate_now()
	bus.first_time.emit(&"gamble_wheel", {})
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.gamble_wheel", "gamble step lights on the cost")
	guide.tick(1.0)
	t.eq(guide.active_step(), "", "gamble step completes")
	guide.queue_free()
	await t.frames(1)
	card.visible = false
	var fresh := _fresh_guide(data, k16)
	(fresh["bus"] as CardEventBus).first_time.emit(&"big_wheel", {"uid": "c0099"})
	(fresh["guide"] as CardGuide).evaluate_now()
	t.eq((fresh["guide"] as CardGuide).active_step(), "gd.big_wheel", "big wheel falls back to the face")
	(fresh["guide"] as Node).queue_free()
	(fresh["bus"] as Node).queue_free()
	await t.frames(1)
	S.face(panel).visible = false
	var dark := _fresh_guide(data, k16)
	(dark["bus"] as CardEventBus).first_time.emit(&"big_wheel", {"uid": "c0100"})
	(dark["guide"] as CardGuide).evaluate_now()
	t.eq((dark["guide"] as CardGuide).active_step(), "", "big wheel stays dark without a card or the face")
	(dark["guide"] as Node).queue_free()
	(dark["bus"] as Node).queue_free()
	panel.queue_free()
	card.queue_free()
	bus.queue_free()
	await t.frames(2)


# K16 production steps (data/cards/guide/steps.json, not the W1 1s fixture).
# gd.m.open needs month_open and finishes on panel:wheel.
# gd.m.wheel needs phase month_open and panel wheel; finishes on wheel.offer, wheel.spin or got it.
# K16 10-22 (prototype): got it on the wheel bubble lights gd.m.incense before anything is offered;
# gd.m.incense finishes on wheel.offer or wheel.spin. Then the day-phase big / fair / gamble steps.
# While the wheel overlay is still open, gd.big_wheel points at the wheel face (its fallback): the card
# in hand is behind the overlay (button audit b47).
func _k16(t) -> void:
	var pack := S.boot(self)
	var mock: MockCardEngine = pack["mock"]
	var bus: CardEventBus = pack["bus"]
	mock.load_fixture(S.FIX + "month_widen.json")
	var goals := _marker(Vector2(48, 48), Vector2(220, 72))
	CardAnchors.register(&"a.month.goals", goals)
	var card := _marker(Vector2(24, 24), Vector2(96, 120))
	CardAnchors.register(&"a.card@c0099", card)
	_expect_prod(t)
	var data: Dictionary = mock.query(&"guide_data")
	var guide := _guide(bus, mock, data, true)
	await t.frames(1)
	bus.first_time.emit(&"month_open", {})
	guide.evaluate_now()
	_holds(t, guide, "gd.m.open", "a.month.goals")
	var host := CardModalHost.new()
	host.bind(mock, bus)
	root.add_child(host)
	var panel := host.open_panel(&"wheel", S.args_of(S.read_fix("month_widen")))
	await t.frames(2)
	t.ok(panel is CardWheelPanel, "wheel panel is open")
	t.eq(str(mock.view().get("phase", "")), "month_open", "phase is month_open")
	t.eq(guide.active_step(), "", "panel:wheel completes gd.m.open")
	t.ok(t.anchor_ok(&"a.wheel.face"), "k16 face anchor")
	t.ok(t.anchor_ok(&"a.wheel.incense"), "k16 incense anchor")
	t.ok(t.anchor_ok(&"a.wheel.cost"), "k16 cost anchor")
	bus.first_time.emit(&"month_wheel", {})
	guide.evaluate_now()
	_holds(t, guide, "gd.m.wheel", "a.wheel.face")
	guide.acknowledge()
	t.eq(guide.active_step(), "", "got it completes gd.m.wheel")
	guide.evaluate_now()
	_holds(t, guide, "gd.m.incense", "a.wheel.incense")
	bus.command_done.emit(&"wheel.offer", {}, true)
	t.eq(guide.active_step(), "", "wheel.offer completes gd.m.incense")
	mock._view["phase"] = "day"
	bus.first_time.emit(&"big_wheel", {"uid": "c0099"})
	guide.evaluate_now()
	_holds(t, guide, "gd.big_wheel", "a.wheel.face")
	bus.command_done.emit(&"wheel.spin", {}, true)
	t.eq(guide.active_step(), "", "wheel.spin completes gd.big_wheel")
	bus.first_time.emit(&"fair_wheel", {})
	guide.evaluate_now()
	_holds(t, guide, "gd.fair_wheel", "a.wheel.cost")
	bus.command_done.emit(&"wheel.stake", {}, true)
	t.eq(guide.active_step(), "", "wheel.stake completes gd.fair_wheel")
	bus.first_time.emit(&"gamble_wheel", {})
	guide.evaluate_now()
	_holds(t, guide, "gd.gamble_wheel", "a.wheel.cost")
	bus.command_done.emit(&"wheel.spin", {}, true)
	t.eq(guide.active_step(), "", "wheel.spin completes gd.gamble_wheel")
	t.eq(Array(guide.shown_log), ["gd.m.open", "gd.m.wheel", "gd.m.incense", "gd.big_wheel", "gd.fair_wheel", "gd.gamble_wheel"], "k16 step ids")
	guide.queue_free()
	host.queue_free()
	goals.queue_free()
	card.queue_free()
	bus.queue_free()
	await t.frames(2)


func _holds(t, guide: CardGuide, id: String, anchor: String) -> void:
	t.eq(guide.active_step(), id, id + " lights")
	t.eq(str(guide._anchor_now), anchor, id + " anchor")
	t.ok(t.anchor_ok(StringName(anchor)), id + " anchor in view")
	guide.tick(1.0)
	t.eq(guide.active_step(), id, "1s does not finish " + id)


func _marker(at: Vector2, sz: Vector2) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = CardTheme.color(&"paper")
	rect.position = at
	rect.size = sz
	root.add_child(rect)
	return rect


func _expect_prod(t) -> void:
	_expect_step(t, "gd.m.open", "month_open", "month_open", "", [], ["panel:wheel", "timeout"], "a.month.goals")
	_expect_step(t, "gd.m.wheel", "month_wheel", "month_open", "wheel", [], ["cmd:wheel.offer", "cmd:wheel.spin", "timeout"], "a.wheel.face")
	_expect_step(t, "gd.m.incense", "", "month_open", "wheel", ["gd.m.wheel"], ["cmd:wheel.offer", "cmd:wheel.spin", "timeout"], "a.wheel.incense")
	_expect_step(t, "gd.big_wheel", "big_wheel", "day", "", [], ["panel:wheel", "cmd:wheel.spin", "timeout"], "a.card@{uid}")
	_expect_step(t, "gd.fair_wheel", "fair_wheel", "", "wheel", [], ["cmd:wheel.stake", "cmd:wheel.spin", "timeout"], "a.wheel.cost")
	_expect_step(t, "gd.gamble_wheel", "gamble_wheel", "", "wheel", [], ["cmd:wheel.spin", "timeout"], "a.wheel.cost")


func _expect_step(t, id: String, first: String, phase: String, panel: String, after: Array, done: Array, anchor: String) -> void:
	var step: Dictionary = _prod_step(id)
	var trig: Dictionary = step.get("trigger", {})
	t.eq(str(trig.get("first", "")), first, id + " first stays")
	t.eq(str(trig.get("phase", "")), phase, id + " phase stays")
	t.eq(str(trig.get("panel", "")), panel, id + " panel stays")
	t.eq(trig.get("after", []), after, id + " after stays")
	t.eq(step.get("done_when", []), done, id + " done_when stays")
	t.eq(str(step.get("anchor", "")), anchor, id + " anchor id stays")
	# K16 10-22: seconds 0 = no clock (the bubble stays until the deed or got it); never the W1 1s tick.
	t.ok(float(step.get("seconds", 0)) == 0.0 or float(step.get("seconds", 0)) > 1.0, id + " seconds are not the W1 1s tick")


func _prod_step(id: String) -> Dictionary:
	var doc = CardDB.read_json("res://data/cards/guide/steps.json")
	if typeof(doc) != TYPE_DICTIONARY:
		return {}
	var cards = doc.get("cards", [])
	if typeof(cards) != TYPE_ARRAY:
		return {}
	for step in cards:
		if typeof(step) != TYPE_DICTIONARY:
			continue
		if str(step.get("id", "")) == id:
			return step
	return {}


func _fresh_guide(data, k16: bool) -> Dictionary:
	var pack := S.boot(self)
	return {"bus": pack["bus"], "mock": pack["mock"], "guide": _guide(pack["bus"], pack["mock"], data, k16)}


func _guide(bus: CardEventBus, mock: MockCardEngine, data, k16: bool) -> CardGuide:
	var guide := CardGuide.new()
	root.add_child(guide)
	guide.bind(mock, bus)
	if k16:
		guide.load_steps(mock.query(&"guide_data"))
	else:
		guide.load_steps(data)
	guide.force(true)
	guide.skip_fades = true
	return guide


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback
