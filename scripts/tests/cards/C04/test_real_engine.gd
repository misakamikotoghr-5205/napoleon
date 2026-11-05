# Real CardEngine, seed 7, day 1. The three counter guests each open once and finish.
# Example-set day 1 is scripted and deals nobody (W0_engine). The three guests are the
# full-set tutorial trio. Fair sell + fair pawn is more than the starting purse, so the
# sale is served first, then the buyer (puts cash back), then the pawn. autoplay_step.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")


func _initialize() -> void:
	var t := T.new(self, _arg("--name=", "C04_real_engine"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	await t.frames(1)
	var eng := CardEngine.new(bus)
	var started: Dictionary = eng.new_game({
		"seed": 7,
		"only_examples": false,
		"save_dir": t.user_dir(),
	})
	t.ok(bool(started.get("ok", false)), "real new_game")
	t.eq(str(eng.view().get("phase", "")), "month_open", "new game waits at month open")
	var spun: Dictionary = eng.send(&"wheel.spin", {"wheel": "wh.month", "uid": ""})
	t.ok(bool(spun.get("ok", false)), "month wheel")
	var month: Dictionary = eng.send(&"month.begin", {})
	t.ok(bool(month.get("ok", false)), "month begin")
	var day: Dictionary = eng.send(&"day.begin", {})
	t.ok(bool(day.get("ok", false)), "day begin")
	var date: Dictionary = eng.view().get("date", {})
	t.eq(int(date.get("abs_day", -1)), 1, "absolute day 1")
	t.eq(int(date.get("stage_day", -1)), 1, "stage day 1")
	var guests: Array = _counter_guests(eng)
	t.eq(guests.size(), 3, "day 1 has three counter guests")
	var intents: Array = []
	for row in guests:
		intents.append(str((row as Dictionary).get("intent", "")))
	intents.sort()
	t.eq(intents, ["buy", "pawn", "sell"], "guests are pawn, sell, and buy")
	for uid in _serve_order(guests):
		await _serve(t, eng, bus, uid)
		t.ok(not _in_hand(eng, uid), "guest finished " + uid)
		t.eq(_opens(eng, uid), 1, "counter opened once " + uid)
	t.eq(_counter_guests(eng).size(), 0, "no counter guest left on day 1")
	t.eq(_ledger_errors(eng), [], "ledger has no errors")
	bus.queue_free()
	await t.frames(2)


func _serve(t, eng: CardEngine, bus: CardEventBus, uid: String) -> void:
	var panel := CardCounterPanel.new()
	root.add_child(panel)
	panel.bind(eng, bus)
	await t.frames(1)
	panel.open({"uid": uid})
	await t.frames(1)
	var steps := 0
	var going := true
	while going and steps < 16:
		going = panel.autoplay_step()
		steps += 1
		await t.frames(1)
	t.ok(not going, "autoplay finished " + uid)
	panel.queue_free()
	await t.frames(2)


func _counter_guests(eng: CardEngine) -> Array:
	var out: Array = []
	var hand: Array = eng.view().get("hand", [])
	for row in hand:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = row
		if str(card.get("panel", "")) != "counter":
			continue
		var uid := str(card.get("uid", ""))
		var full: Dictionary = eng.query(&"card", {"uid": uid})
		out.append({"uid": uid, "intent": str(full.get("intent", ""))})
	return out


func _serve_order(guests: Array) -> Array:
	var by := {}
	for row in guests:
		var card: Dictionary = row
		by[str(card.get("intent", ""))] = str(card.get("uid", ""))
	var out: Array = []
	for intent in ["sell", "buy", "pawn", "redeem"]:
		if by.has(intent):
			out.append(str(by[intent]))
	return out


func _in_hand(eng: CardEngine, uid: String) -> bool:
	for row in eng.view().get("hand", []):
		if typeof(row) == TYPE_DICTIONARY and str(row.get("uid", "")) == uid:
			return true
	return false


func _opens(eng: CardEngine, uid: String) -> int:
	var n := 0
	for row in eng.command_log():
		if typeof(row) != TYPE_ARRAY or (row as Array).size() < 2:
			continue
		var rec: Array = row
		if str(rec[0]) != "counter.open":
			continue
		if typeof(rec[1]) != TYPE_DICTIONARY:
			continue
		var args: Dictionary = rec[1]
		if str(args.get("uid", "")) == uid:
			n += 1
	return n


func _ledger_errors(eng: CardEngine) -> Array:
	var ledger = eng.ctx.ledger
	if ledger == null:
		return ["missing"]
	var found = ledger.check_invariants()
	if typeof(found) != TYPE_ARRAY:
		return ["not_array"]
	return found


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback
