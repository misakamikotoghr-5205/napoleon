# 五个种子的真实六模块三关浸泡，完整输出检查且每条指令保持规定事件收尾。
# 数据仅为 W0 私有补全年份夹具；正式数据缺口见 issue #49。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/G02/helpers.gd")
const Scenario = preload("res://scripts/tests/cards/G02/real_scenario.gd")
const Real = preload("res://scripts/tests/cards/G02/real_firsts.gd")

func _initialize() -> void:
	var t := T.new(self, "G02_real_three_stages")
	var data_root := Scenario.build(t.user_dir() + "/data")
	# Private endurance fixture removes bankruptcy/arrest endings so all loop transitions are exercised.
	var economy: Dictionary = CardState.int_restore(CardDB.read_json(data_root + "/rules/economy.json"))
	economy["start_money"] = 100000
	preload("res://scripts/tests/cards/G02/helpers.gd")._write(data_root + "/rules/economy.json", JSON.stringify(economy))
	var meters: Dictionary = CardState.int_restore(CardDB.read_json(data_root + "/rules/meters.json"))
	meters["heat"]["arrest_at"] = 1000000
	preload("res://scripts/tests/cards/G02/helpers.gd")._write(data_root + "/rules/meters.json", JSON.stringify(meters))
	for seed_value in range(5):
		_soak(t, data_root, seed_value)
	t.finish()

func _soak(t: RefCounted, data_root: String, seed_value: int) -> void:
	var bus := CardEventBus.new()
	var e := CardEngine.new(bus)
	var spy = t.spy(bus)
	var seen: Dictionary = {}
	bus.command_done.connect(func(_cmd: StringName, _args: Dictionary, _ok: bool) -> void:
		var loop := e.ctx.state.ns("loop") if e.ctx.state != null else {}
		var key := "%s:%s" % [loop.get("abs_day", 0), loop.get("phase", "")]
		if seen.has(key): return
		seen[key] = true
		var before := e.state_hash()
		var view := e.view()
		t.no_leaks(view, "real soak view")
		t.eq(view, e.view(), "real soak stable view")
		for q in e._queries.keys():
			t.no_leaks(e.query(q), "real soak query %s" % q)
		for card in view.get("hand", []):
			t.no_leaks(e.query(&"card", {"uid": str(card["uid"])}), "real soak card")
			t.no_leaks(e.query(&"actions", {"uid": str(card["uid"])}), "real soak actions")
		t.eq(e.state_hash(), before, "real soak views and queries read only"))
	t.ok(bool(e.new_game({"seed": seed_value, "data_root": data_root, "only_examples": true,
		"save_dir": t.user_dir() + "/saves_%d" % seed_value}).get("ok")), "real new game")
	for stage in range(3):
		_advance(t, e, &"wheel.spin", {"wheel": "wh.month", "uid": ""})
		_advance(t, e, &"month.begin")
		for _day in range(30):
			_advance(t, e, &"day.begin")
			_advance(t, e, &"day.end", {"confirm": true})
			var offers: Array = e.view()["night_offers"]
			var id := H.offer_def(offers[0])
			for offer in offers:
				if H.offer_def(offer) == "nt.tidy": id = "nt.tidy"
			var args := {"def": id}
			for row in offers:
				if H.offer_def(row) == id and not row["choices"].is_empty(): args["choice"] = str(row["choices"][0])
			_advance(t, e, &"night.choose", args)
			_advance(t, e, &"settle.next")
		_advance(t, e, &"month.next")
		if stage < 2: _advance(t, e, &"year.next")
	t.eq(e.view()["phase"], "game_over", "real final phase seed%d" % seed_value)
	t.eq(e.view()["game_over_reason"], "ending", "real release ending seed%d" % seed_value)
	t.eq(e.ctx.abs_day(), 90, "real ninety days seed%d" % seed_value)
	for i in range(spy.log.size()):
		Real._event_leaks(t, spy.log[i], seed_value)
		if spy.log[i][0] == &"command_done":
			t.ok(i + 1 < spy.log.size() and spy.log[i + 1][0] == &"view_changed", "command ends in view changed")
	t.eq(t.find_floats(e.ctx.state.data), PackedStringArray(), "real integer state")
	print("G02 REAL SOAK " + JSON.stringify({"seed_no": seed_value, "days": e.ctx.abs_day(),
		"stages": int(e.view()["date"]["stage"]) + 1, "hash": e.state_hash()}, "", true))
	bus.free()


func _advance(t: RefCounted, e: CardEngine, cmd: StringName, args: Dictionary = {}) -> void:
	var result := e.send(cmd, args)
	t.ok(bool(result.get("ok", false)), "real soak command %s: %s" % [cmd, result.get("err", "")])

