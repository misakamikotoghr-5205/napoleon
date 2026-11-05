# G02 测试辅助：独立数据根与指令脚本，循环单测只安装循环钩子。
# 真实模块的组合验证由全量集成工作区补跑，夹具不写玩家正文。
extends RefCounted

static func engine(t: RefCounted, seed_value: int = 7) -> CardEngine:
	var root_path: String = t.user_dir() + "/data"
	DirAccess.make_dir_recursive_absolute(root_path + "/rules")
	for f in CardDB.list_json("res://data/cards/rules"):
		_write(root_path + "/rules/" + f.get_file(), FileAccess.get_file_as_string(f))
	DirAccess.make_dir_recursive_absolute(root_path + "/common")
	_write(root_path + "/common/test.json", FileAccess.get_file_as_string("res://scripts/tests/cards/G02/fixtures/cards.json"))
	for era in ["1938", "1939", "1940"]:
		DirAccess.make_dir_recursive_absolute(root_path + "/era/" + era)
		_write(root_path + "/era/" + era + "/stage.json", JSON.stringify({"era": era, "bg": "bg.test", "intro_paras": 1, "main_goal": "gl.test.main"}))
	var e := CardEngine.new()
	t.ok(bool(e.new_game({"seed": seed_value, "data_root": root_path, "save_dir": t.user_dir()}).get("ok", false)), "fixture new game")
	var hooks := CardHooks.new()
	for name in e.ctx.hooks._hooks.keys():
		for row in e.ctx.hooks._hooks[name]:
			if str(row["owner"]) == "G02":
				hooks.on(name, row["fn"], int(row["priority"]), "G02")
	e.ctx.hooks = hooks
	# Module substitutes expose only notice effects, enough to test collection and ordering.
	e.ctx.ops._ops[&"notice"]["handler"] = func(c: CardCtx, eff: Dictionary, _source: String) -> void:
		c.emit(&"notice", [str(eff["key"]), eff.get("args", {})])
	e.ctx.mods = CardMods.new()
	e.ctx.mods.register(&"hand_sub", CardLoopInstall._mod_hand_sub, "G02")
	e.ctx.mods.register(&"scheduled_cards", CardLoopInstall._mod_scheduled, "G02")
	e.ctx.mods.register(&"end_rows", preload("res://scripts/cards/loop/end_day_rules.gd").own_rows, "G02")
	CardDayLoop.request_panel(e.ctx, &"", {})
	e.ctx.out = []
	return e

static func morning(t: RefCounted, e: CardEngine) -> void:
	t.ok(bool(e.send(&"month.begin").get("ok", false)), "enter morning")

static func play_day(t: RefCounted, e: CardEngine, inspect: bool = false) -> void:
	for cmd in [&"day.begin", &"day.end", &"night.choose", &"settle.next"]:
		var args := {"confirm": true} if cmd == &"day.end" else {}
		if cmd == &"night.choose":
			var offers: Array = e.view()["night_offers"]
			t.eq(offers.size(), 3, "night offers three distinct cards")
			if offers.is_empty():
				return
			var def_id := offer_def(offers[0])
			args = {"def": def_id}
			var choices: Array = offers[0].get("choices", []) if typeof(offers[0]) == TYPE_DICTIONARY else []
			if not choices.is_empty():
				args["choice"] = str(choices[0])
		t.ok(bool(e.send(cmd, args).get("ok", false)), "progress %s" % cmd)
		if inspect:
			t.no_leaks(e.view())
			t.eq(e.view(), e.view(), "stable view at %s" % cmd)
			t.eq(t.find_floats(e.ctx.state.data), PackedStringArray(), "integer state at %s" % cmd)

static func play_three(t: RefCounted, e: CardEngine, inspect: bool = false) -> void:
	for stage in range(3):
		morning(t, e)
		for _day in range(30):
			play_day(t, e, inspect)
		t.eq(e.view()["phase"], "month_close", "month closes at day30")
		t.ok(bool(e.send(&"month.next").get("ok", false)), "month next")
		if stage < 2:
			t.eq(e.view()["phase"], "year_jump", "year jump phase")
			t.ok(bool(e.send(&"year.next").get("ok", false)), "next stage")
	t.eq(e.view()["phase"], "game_over", "first release ending")
	t.eq(e.ctx.abs_day(), 90, "ninety days")

static func without_resume(st: CardState) -> String:
	var copy := CardState.from_dict(st.to_dict())
	copy.ns("core")["firsts"].erase("resume")
	copy.ns("core")["firsts"].erase("retry")
	return copy.hash()


static func offer_def(row) -> String:
	return str(row.get("def", "")) if typeof(row) == TYPE_DICTIONARY else str(row)

static func _write(path: String, text_value: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text_value)
	f.close()

