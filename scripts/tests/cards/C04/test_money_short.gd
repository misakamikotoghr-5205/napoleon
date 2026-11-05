# [shared] G04 10-25 (orchestrator bug): on tutorial day 1, after the pawn is paid out, the sell guest's fair price
# is more than the purse (the test tops the purse down if the day-1 data leaves enough). The fair reply must be disabled with the reason "money_short"; Enter (which picks the
# fair price by default) must do nothing; nothing may be narrated as a done deal; money, shelf and hand unchanged.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const E = preload("res://scripts/cards/economy/economy_support.gd")


func _initialize() -> void:
	var t := T.new(self, "C04_money_short")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	await t.frames(1)
	var eng := CardEngine.new(bus)
	t.ok(bool(eng.new_game({"seed": 7, "only_examples": false, "save_dir": t.user_dir()}).get("ok", false)), "real new_game")
	eng.send(&"wheel.spin", {"wheel": "wh.month", "uid": ""})
	eng.send(&"month.begin", {})
	eng.send(&"day.begin", {})
	var by := _guests(eng)
	t.ok(by.has("pawn") and by.has("sell"), "tutorial day 1 has a pawn and a sell guest")
	if not (by.has("pawn") and by.has("sell")):
		bus.queue_free()
		return
	await _autoplay(t, eng, bus, str(by["pawn"]))
	var sell := str(by["sell"])
	# The orchestrator's repro is "pawn first, then the sell guest at the fair price". How much the pawn leaves in
	# the purse depends on the day-1 data, so make sure the fair price is beyond it before the sell guest opens.
	var opened: Dictionary = eng.send(&"counter.open", {"uid": sell})
	var fair_price := int(opened.get("tiers", {}).get("fair", 0))
	var purse := int(eng.view().get("money", {}).get("amount", 0))
	if purse >= fair_price:
		E.transfer(eng.ctx, "player", "world", purse - (fair_price - 1), "g04.reason.test")
	var panel := CardCounterPanel.new()
	root.add_child(panel)
	panel.bind(eng, bus)
	await t.frames(1)
	panel.open({"uid": sell})
	await t.frames(2)
	var cv: Dictionary = eng.query(&"counter", {"uid": sell})
	var money := int(eng.view().get("money", {}).get("amount", 0))
	t.ok(int(cv.get("tiers", {}).get("fair", 0)) > money, "precondition: the fair price is beyond the purse after the pawn")
	t.eq(str(cv.get("tier_err", {}).get("fair", "")), "money_short", "engine says why the fair price cannot be paid")
	var fair := _row(panel._replies(), "tier:fair")
	t.eq(bool(fair.get("enabled", true)), false, "fair reply is disabled")
	t.eq(str(fair.get("reason_ref", "")), "c04.reason.money_short", "fair reply shows the money-short reason")
	t.ok(CardText.t("c04.reason.money_short") != "", "reason text exists")
	var shelf_before := (eng.query(&"stock", {}).get("items", []) as Array).size()
	var log_before := eng.command_log().size()
	if panel.dialog != null:
		panel.dialog.skip()
		await t.frames(1)
	t.ok(panel.confirm_key(), "Enter is swallowed by the counter")
	await t.frames(1)
	t.eq(eng.command_log().size(), log_before, "Enter sends nothing for a price the shop cannot pay")
	t.eq(int(eng.view().get("money", {}).get("amount", 0)), money, "money unchanged")
	t.eq((eng.query(&"stock", {}).get("items", []) as Array).size(), shelf_before, "shelf unchanged")
	t.ok(_in_hand(eng, sell), "the sell guest is still in hand")
	var now: Dictionary = eng.query(&"counter", {"uid": sell})
	t.ok(str(now.get("last_reply", "")) != "accept", "never recorded as accepted")
	t.ok(not str(panel._cv.get("line_key", "")).ends_with("#lines.accept"), "never narrated as a done deal")
	var direct: Dictionary = eng.send(&"counter.offer", {"uid": sell, "tier": "fair"})
	t.eq(str(direct.get("err", "")), "money_short", "the engine refuses the deal with money_short")
	t.ok(_in_hand(eng, sell), "still in hand after the refused offer")
	var steps := 0
	var going := true
	while going and steps < 16:
		going = panel.autoplay_step()
		steps += 1
		await t.frames(1)
	t.ok(not going, "autoplay finds an affordable price or turns the guest away")
	panel.queue_free()
	bus.queue_free()
	await t.frames(2)


func _autoplay(t, eng: CardEngine, bus: CardEventBus, uid: String) -> void:
	var panel := CardCounterPanel.new()
	root.add_child(panel)
	panel.bind(eng, bus)
	await t.frames(1)
	panel.open({"uid": uid})
	await t.frames(1)
	var steps := 0
	while steps < 16 and panel.autoplay_step():
		steps += 1
		await t.frames(1)
	t.ok(not _in_hand(eng, uid), "pawn guest served first")
	panel.queue_free()
	await t.frames(2)


func _guests(eng: CardEngine) -> Dictionary:
	var by := {}
	for row in eng.view().get("hand", []):
		if typeof(row) != TYPE_DICTIONARY or str(row.get("panel", "")) != "counter":
			continue
		var full: Dictionary = eng.query(&"card", {"uid": str(row.get("uid", ""))})
		by[str(full.get("intent", ""))] = str(row.get("uid", ""))
	return by


func _row(rows: Array, id: String) -> Dictionary:
	for r in rows:
		if typeof(r) == TYPE_DICTIONARY and str(r.get("id", "")) == id:
			return r
	return {}


func _in_hand(eng: CardEngine, uid: String) -> bool:
	for row in eng.view().get("hand", []):
		if typeof(row) == TYPE_DICTIONARY and str(row.get("uid", "")) == uid:
			return true
	return false
