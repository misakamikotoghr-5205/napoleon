# W2 real CardEngine, seed 7, save_dir from the test user dir.
# Contract 4.10: W2 integration uses the real card set, not the example set.
# The example set's scripted day 1 deals nobody and does not load obs/spot.json.
# Day-1 tutorial guest: mg.request -> G04 params -> autoplay(0.8) -> mg.report
# stores observations on the item.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Lib = preload("res://scripts/tests/cards/C12/c12_lib.gd")

const TUTORIAL_DEF := "p.zhang.1938.tut_pawn"


func _initialize() -> void:
	var test_name := "C12_real_engine"
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--name="):
			test_name = str(a).substr(7)
	var t := T.new(self, test_name)
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	await t.frames(1)
	var engine := CardEngine.new(bus)
	var script: Script = engine.get_script()
	t.eq(script.resource_path, "res://scripts/cards/loop/card_engine.gd", "real CardEngine")
	t.eq(engine.command_owner(&"mg.request"), "G04", "G04 owns mg.request")
	t.eq(engine.command_owner(&"mg.report"), "G04", "G04 owns mg.report")
	var started: Dictionary = engine.new_game({
		"seed": 7,
		"only_examples": false,
		"save_dir": t.user_dir(),
	})
	t.ok(bool(started.get("ok", false)), "new_game " + str(started.get("err", "")))
	t.ok(not engine.ctx.db.only_examples, "real card set")
	var spun: Dictionary = engine.send(&"wheel.spin", {"wheel": "wh.month", "uid": ""})
	t.ok(bool(spun.get("ok", false)), "month wheel " + str(spun.get("err", "")))
	var month: Dictionary = engine.send(&"month.begin", {})
	t.ok(bool(month.get("ok", false)), "month.begin " + str(month.get("err", "")))
	var day: Dictionary = engine.send(&"day.begin", {})
	t.ok(bool(day.get("ok", false)), "day.begin " + str(day.get("err", "")))
	t.eq(int(engine.view().get("date", {}).get("stage_day", 0)), 1, "stage day 1")
	var guest := _tutorial_guest(engine)
	t.ok(guest != "", "day-1 tutorial guest")
	if guest != "":
		await _appraise(t, engine, bus, guest)
	bus.queue_free()
	await t.frames(2)


func _appraise(t, engine: CardEngine, bus: CardEventBus, guest: String) -> void:
	var card_q: Dictionary = engine.query(&"card", {"uid": guest})
	var def_id := str(card_q.get("def", ""))
	t.eq(str(engine.ctx.db.def(def_id).get("id", "")), TUTORIAL_DEF, "tutorial pawn")
	var opened: Dictionary = engine.send(&"counter.open", {"uid": guest})
	t.ok(bool(opened.get("ok", false)), "counter.open " + str(opened.get("err", "")))
	var item := _item_id(opened.get("item"))
	t.ok(item != "", "guest item")
	var req: Dictionary = engine.send(&"mg.request", {"uid": guest, "item": item})
	t.ok(bool(req.get("ok", false)), "mg.request " + str(req.get("err", "")))
	t.eq(str(req.get("kind", "")), "spot", "G04 kind")
	var params := _dict(req.get("params", {}))
	var parts: Variant = params.get("parts", [])
	t.ok(typeof(parts) == TYPE_ARRAY and (parts as Array).size() > 0, "G04 spot layout")
	var game := Lib.open_game(self, params)
	game.bind_bus(bus)
	await t.frames(2)
	var box: Array = []
	game.finished.connect(func(result: Dictionary) -> void: box.append(result))
	game.autoplay(0.8)
	t.eq(box.size(), 1, "autoplay finished once")
	var played_raw: Variant = {}
	if box.size() == 1:
		played_raw = box[0]
	var played := _dict(played_raw)
	t.eq(bool(played.get("aborted", true)), false, "not aborted")
	var seen: Variant = played.get("observations", [])
	t.ok(typeof(seen) == TYPE_ARRAY and (seen as Array).size() > 0, "autoplay observations")
	var rep: Dictionary = engine.send(&"mg.report", {"uid": guest, "item": item, "result": played})
	t.ok(bool(rep.get("ok", false)), "mg.report " + str(rep.get("err", "")))
	var accepted: Variant = rep.get("observations", [])
	t.ok(typeof(accepted) == TYPE_ARRAY and (accepted as Array).size() > 0, "report kept observations")
	var again: Dictionary = engine.query(&"counter", {"uid": guest})
	var stored: Variant = _dict(again.get("item")).get("observations", [])
	t.ok(typeof(stored) == TYPE_ARRAY and (stored as Array).size() > 0, "item observations")
	if typeof(accepted) == TYPE_ARRAY and typeof(stored) == TYPE_ARRAY:
		var kept: Array = accepted
		var on_item: Array = stored
		for key in kept:
			t.ok(on_item.has(key), "recorded " + str(key))
			t.ok(str(key).begins_with("obs.spot."), "spot key " + str(key))
	game.queue_free()
	await t.frames(2)


func _tutorial_guest(engine: CardEngine) -> String:
	var hand: Variant = engine.view().get("hand", [])
	if typeof(hand) != TYPE_ARRAY:
		return ""
	var best_uid := ""
	var best_order := 1000000
	for row in hand:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var card: Dictionary = row
		if str(card.get("type", "")) != "person":
			continue
		var d: Dictionary = engine.ctx.db.def(str(card.get("def", "")))
		if str(d.get("minigame", "")) != "spot":
			continue
		var sch: Variant = d.get("schedule", {})
		if typeof(sch) != TYPE_DICTIONARY:
			continue
		var sched: Dictionary = sch
		if int(sched.get("stage_day", 0)) != 1:
			continue
		var order := int(sched.get("order", 99))
		if order < best_order:
			best_order = order
			best_uid = str(card.get("uid", ""))
	return best_uid


func _item_id(item: Variant) -> String:
	if typeof(item) != TYPE_DICTIONARY:
		return ""
	return str((item as Dictionary).get("item", ""))


func _dict(v: Variant) -> Dictionary:
	if typeof(v) == TYPE_DICTIONARY:
		return v
	return {}
