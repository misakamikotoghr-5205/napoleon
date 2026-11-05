# 循环需求断言：阶段、确认、只读日程、存读、确定性与所有可见输出泄漏检查。
# 测试按主题分清单，使用自己的数据与运行目录。
extends RefCounted

const H = preload("res://scripts/tests/cards/G02/helpers.gd")

static func run(t: RefCounted, case_name: String) -> void:
	match case_name:
		"engine_flow": _engine_flow(t)
		"three_stages": _three(t)
		"view_leaks": _views(t)
		"stage_view": _stage_view(t)
		"gold": _gold(t)
		"schedule": _schedule(t)
		"calendar": _calendar(t)
		"goals": _goals(t)
		"year_jump": _year(t)
		"save_retry": _save(t)
		"determinism": _determinism(t)
		"firsts": _firsts(t)
		"firsts_d1_3": _d1_3(t)

static func _engine_flow(t: RefCounted) -> void:
	var e := H.engine(t)
	var bus := CardEventBus.new()
	e.bus = bus
	e.ctx.bus = bus
	var spy = t.spy(bus)
	var wrong := e.ctx.state.hash()
	t.eq(e.send(&"day.end", {"confirm": "bad"}).get("err"), "bad_args", "in-game day.end validates confirmation type")
	# The 1.1 name confirm_gold_leave was a W1-only alias; W2 removed it (contract §7.4.7).
	t.eq(e.send(&"day.end", {"confirm_gold_leave": true}).get("err"), "bad_args", "removed day.end alias rejected")
	t.eq(e.ctx.state.hash(), wrong, "bad phase doesn't mutate state")
	t.eq(spy.names().slice(-2), [&"command_done", &"view_changed"], "failed command event suffix")
	var log_size := e.command_log().size()
	t.eq(log_size, 3, "failed entered commands logged")
	spy.clear()
	t.ok(bool(e.send(&"ui.guide", {"step": "x", "status": "shown"}).get("ok")), "ui command")
	t.eq(spy.names(), [], "ui emits no event")
	t.eq(e.command_log().size(), log_size, "ui not logged")
	var inner: Array = []
	bus.command_done.connect(func(_cmd: StringName, _args: Dictionary, _ok: bool) -> void:
		inner.append(e.send(&"day.begin")), CONNECT_ONE_SHOT)
	H.morning(t, e)
	t.eq(inner[0].get("err"), "busy", "bus dispatch stays busy")
	t.eq(e.view()["phase"], "morning", "morning distinct from deal")
	t.eq(e.view()["hand"].size() if e.view().has("hand") else CardPiles.list(e.ctx, &"hand").size(), 0, "morning before cards")
	t.ok(CardSave.exists(CardSave.suspend_path()), "morning autosave")
	spy.clear()
	H.play_day(t, e)
	t.eq(spy.names().slice(-2), [&"command_done", &"view_changed"], "success event suffix")
	e.send(&"day.begin")
	e.ctx.state.ns("loop")["night"]["offers"] = ["nt.test.b", "nt.test.a", "nt.test.c"]
	e.send(&"day.end", {"confirm": true})
	e.ctx.state.ns("loop")["night"]["offers"] = ["nt.test.b", "nt.test.a", "nt.test.c"]
	var before := e.ctx.state.hash()
	t.eq(e.send(&"night.choose", {"def": "nt.test.b"}).get("err"), "no_such_choice", "choice required")
	t.eq(e.ctx.state.hash(), before, "invalid night choice no mutation")
	spy.clear()
	t.ok(bool(e.send(&"night.choose", {"def": "nt.test.b", "choice": "one"}).get("ok")), "night choice")
	var notices: Array = []
	for ev in spy.log:
		if ev[0] == &"notice": notices.append(ev[1])
	t.eq(notices.slice(0, 2), ["g02.notice.market_day", "g02.notice.clear"], "choice effects precede on_choose")
	t.eq(e.view()["phase"], "settle", "night leads settle")
	t.eq(e.view()["night_offer_cards"][0]["choices"], [{"id": "one"}, {"id": "two"}], "visible night choices")
	t.eq(e.view()["stage_intro"], {"bg": "bg.test", "intro_paras": 1}, "visible intro metadata")
	t.ok(e.view()["notice"]["news"].any(func(row: Dictionary) -> bool:
		return row["key"] == "g02.notice.market_day"), "all notice effects enter board")
	_flow_report_and_empty(t, e, spy)
	_month_interruption(t)
	bus.free()

static func _flow_report_and_empty(t: RefCounted, e: CardEngine, spy: RefCounted) -> void:
	e.ctx.hooks.on(&"settle", func(c: CardCtx, _a: Dictionary) -> void:
		c.emit(&"notice", ["g02.settle.gold_left", {"n": 2, "ignored_text": "private"}]), 10, "probe")
	e.send(&"settle.next")
	e.ctx.state.ns("loop")["morning_snapshot"] = {"money": CardCurrency.money(e.ctx) - 100, "rep_tier": 0, "heat_tier": 0}
	e.send(&"day.begin")
	e.send(&"day.end", {"confirm": true})
	e.send(&"night.choose", {"def": "nt.test.a"})
	var report: Array = e.query(&"settle_report")["lines"]
	t.ok(report.any(func(row: Dictionary) -> bool: return row == {"key": "g02.settle.money_in", "args": {"money": 100}}), "report compares morning money")
	t.ok(report.any(func(row: Dictionary) -> bool: return row == {"key": "g02.settle.gold_left", "args": {"n": 2}}), "report notices only integer args")
	e.ctx.state.ns("loop")["night"]["offers"] = []
	CardDayLoop.set_phase(e.ctx, &"night")
	t.eq(e.send(&"night.choose", {"def": "nt.test.a"}).get("err"), "bad_args", "nonempty card cannot choose from empty pool")
	t.ok(bool(e.send(&"night.choose", {"def": ""}).get("ok")), "empty night pool has continuation")
	t.eq(e.view()["phase"], "settle", "empty night progresses settle")
	for id in e.ctx.db.ids_of(&"night"):
		e.ctx.db._cards[id]["conditions"] = {"day_gte": 999}
	CardDayLoop.set_phase(e.ctx, &"day")
	t.ok(bool(e.send(&"day.end", {"confirm": true}).get("ok")), "end day progresses with no eligible nights")
	t.eq(e.view()["phase"], "night", "no-content night still supports explicit skip")
	var queued := CardPiles.spawn(e.ctx, "kp.test", &"pending", {"status": "overflow"})
	var log_before := e.command_log().size()
	spy.clear()
	t.eq(e.send(&"settle.next").get("err"), "overflow_pending", "overflow intercepts progress")
	t.eq(e.command_log().size(), log_before, "intercepted command not handled or logged")
	t.eq(spy.names().slice(-2), [&"command_done", &"view_changed"], "overflow event suffix")
	t.ok(bool(e.send(&"ui.guide", {"step": "overflow", "status": "shown"}).get("ok")), "ui allowed during overflow")
	t.ok(bool(e.send(&"game.retry_stage").get("ok")), "retry bypasses overflow")
	t.ok(not CardPiles.list(e.ctx, &"pending").has(queued), "retry resets overflow")

static func _month_interruption(t: RefCounted) -> void:
	var e := H.engine(t)
	e.ctx.state.ns("loop")["stage_day"] = 30
	CardDayLoop.set_phase(e.ctx, &"settle")
	var calls: Array = [0]
	e.ctx.hooks.on(&"month_close", func(c: CardCtx, _a: Dictionary) -> void:
		calls[0] = int(calls[0]) + 1
		if int(calls[0]) == 1: CardDayLoop.request_panel(c, &"short", {"source": "probe"})
		c.emit(&"notice", ["g06.month.interest", {"n": int(calls[0])}]), 10, "probe")
	t.ok(bool(e.send(&"settle.next").get("ok")), "month close interrupt opens short panel")
	var hash_before := e.state_hash()
	t.eq(e.send(&"month.next").get("err"), "short_pending", "debt prompt retains month")
	t.eq(e.state_hash(), hash_before, "pending debt rejection is read only")
	CardDayLoop.request_panel(e.ctx, &"", {})
	t.ok(bool(e.send(&"month.next").get("ok")), "resolved shortage resumes remaining month hooks")
	t.eq(calls[0], 2, "month hooks resume once")
	t.eq(e.view()["phase"], "year_jump", "month continuation reaches year jump")
	var lines: Array = e.query(&"month_report")["lines"]
	t.eq(lines.filter(func(row: Dictionary) -> bool: return row["key"] == "g06.month.interest").size(), 2, "month report retains both hook notices")

static func _three(t: RefCounted) -> void:
	for seed_value in range(5):
		var e := H.engine(t, seed_value)
		H.play_three(t, e)
		t.ok(not CardFirsts.all(e.ctx).has("branch_pick"), "reserved branch unreachable")
		t.eq(e.view()["game_over_reason"], "ending", "visible ending reason")
		t.eq(e.state_hash(), e.ctx.state.hash(), "safe state hash diagnostic")

static func _views(t: RefCounted) -> void:
	var e := H.engine(t)
	var bus := CardEventBus.new()
	e.bus = bus
	var spy = t.spy(bus)
	e.ctx.mods.register(&"view_section", func(_c: CardCtx, _a: Dictionary) -> Dictionary:
		return {"extension": [{"id": "test", "n": 7}]}, "test")
	e.ctx.mods.register(&"card_view_part", func(_c: CardCtx, _a: Dictionary) -> Dictionary:
		return {"extension_card": "test"}, "test")
	t.eq(e.view().get("extension"), [{"id": "test", "n": 7}], "module view extension")
	var uid := CardPiles.spawn(e.ctx, "kp.test", &"kept")
	t.eq(e.query(&"card", {"uid": uid}).get("extension_card"), "test", "module card extension")
	H.play_three(t, e, true)
	for q in e._queries.keys():
		t.no_leaks(e.query(q, {"uid": uid}), "query %s" % q)
	for ev in spy.log:
		t.no_leaks(ev.slice(1), "event %s" % ev[0])
	for path in CardDB.list_json("res://scripts/cards/mock/fixtures"):
		var fixture: Dictionary = CardDB.read_json(path)
		t.no_leaks(fixture.get("view", {}), path.get_file())
		t.no_leaks(fixture.get("queries", {}), path.get_file() + " queries")
	t.eq(Array(CardViewModel.leaks({"nested": [{"prob": 1}]})), ["nested[0].prob"], "recursive leak path")
	bus.free()


static func _stage_view(t: RefCounted) -> void:
	var e := H.engine(t)
	var loop := e.ctx.state.ns("loop")
	loop["phase"] = "day"
	loop["mode"] = "shop"
	var dealt: Array = []
	for _i in range(5):
		dealt.append(CardPiles.spawn(e.ctx, "p.test.single", CardIds.ZONE_HAND))
	e.ctx.state.ns("core")["deals"][str(e.ctx.abs_day())] = dealt.duplicate()
	t.eq(e.view()["stage"], {"set": "counter", "time": "day", "sealed": false}, "fresh day stage")
	for i in range(2):
		CardPiles.move(e.ctx, dealt[i], CardIds.ZONE_DISCARD)
	t.eq(e.view()["stage"]["time"], "day", "two of five remains day")
	CardPiles.move(e.ctx, dealt[2], CardIds.ZONE_DISCARD)
	t.eq(e.view()["stage"]["time"], "dusk", "three of five reaches dusk")
	loop["phase"] = "night"
	t.eq(e.view()["stage"]["time"], "night", "night phase stage")
	loop["phase"] = "settle"
	t.eq(e.view()["stage"]["time"], "night", "settle phase stage")
	loop["phase"] = "day"
	loop["mode"] = "street"
	t.eq(e.view()["stage"]["set"], "street", "street stage")
	e.ctx.state.ns("ladder")["prison"] = {"uid": "prison-test"}
	t.eq(e.view()["stage"]["set"], "prison", "prison overrides street")
	e.ctx.state.ns("ladder")["prison"] = {"uid": ""}
	e.ctx.state.ns("econ")["shop_closed_until"] = e.ctx.abs_day()
	t.ok(bool(e.view()["stage"]["sealed"]), "same-day closure seals shop")
	e.ctx.state.ns("econ")["shop_closed_until"] = e.ctx.abs_day() - 1
	t.ok(not bool(e.view()["stage"]["sealed"]), "expired closure opens shop")
	var person_uid := CardPiles.spawn(e.ctx, "p.test.single", CardIds.ZONE_HAND)
	var person_view := CardViewModel.card_view(e.ctx, person_uid, true)
	t.eq(person_view["stage"]["cast"][0], {"who": "brother", "at": "customer"}, "stage strips cast brief")
	t.eq(person_view["stage"]["intro"][0], {"who": "brother", "ref": "#intro.1"}, "stage strips intro brief")
	t.eq(person_view["stage"]["after"]["accept"][0], {"who": "brother", "ref": "#accept.1"}, "stage strips nested brief")
	t.eq(person_view["source"], "", "non-news source hidden")
	var news_uid := CardPiles.spawn(e.ctx, "nw.test.source", CardIds.ZONE_HAND)
	var news_view := CardViewModel.card_view(e.ctx, news_uid, true)
	t.eq(news_view["stage"], {}, "card without stage exposes empty object")
	t.eq(news_view["source"], "brother", "news source visible")
	loop["night"] = {"offers": ["nt.test.b"], "chosen": "", "choice": ""}
	t.eq(e.view()["night_offers"], [{"def": "nt.test.b", "art": "illus.nt.test.b", "choices": ["one", "two"]}], "night offers expand view only")
	t.no_leaks(e.view(), "stage view")
	t.no_leaks(person_view, "staged card view")

static func _gold(t: RefCounted) -> void:
	var e := H.engine(t)
	H.morning(t, e)
	H.play_day(t, e)
	e.send(&"day.begin")
	var uid := CardGoldRule.pending(e.ctx)[0]
	t.eq(CardPiles.list(e.ctx, &"hand")[0], uid, "gold sorted first")
	t.eq(CardPiles.keep(e.ctx, uid), "not_keepable", "gold cannot carry")
	var snapshot_path: String = t.user_dir() + "/gold.json"
	CardSave.write(snapshot_path, e.ctx.state, {})
	e.load_game(snapshot_path)
	t.eq(CardGoldRule.pending(e.ctx), PackedStringArray([uid]), "unresolved gold survives load")
	var r := e.send(&"day.end")
	t.eq(r.get("err"), "must_resolve_pending", "gold confirmation prompt")
	t.eq(e.view()["phase"], "day", "prompt stays day")
	t.eq(r["items"].filter(func(row: Dictionary) -> bool: return row["kind"] == "gold_leave").map(func(row: Dictionary) -> String: return row["uid"]), [uid], "visible pending UID")
	var h := e.ctx.state.hash()
	e.send(&"day.end")
	t.eq(e.ctx.state.hash(), h, "repeat prompt changes no state")
	t.ok(bool(e.send(&"day.end", {"confirm": true}).get("ok")), "confirm proceeds")
	t.eq(CardPiles.zone_of(e.ctx, uid), &"discard", "gold discarded")
	t.eq(e.ctx.state.ns("loop")["gold_left"], [uid], "gold departure report source")
	e.send(&"night.choose", {"def": "nt.test.a"})
	t.ok(e.query(&"settle_report")["lines"].any(func(row: Dictionary) -> bool:
		return row["key"] == "g02.settle.gold_left"), "gold report line")
	e.send(&"settle.next")
	t.ok(not CardPiles.list(e.ctx, &"hand").has(uid), "gold absent next day")
	# v1.3 ordinary cards are confirmable even with a panel open.
	e.send(&"day.begin")
	var person := CardPiles.spawn(e.ctx, "p.test.single", &"hand")
	CardDayLoop.request_panel(e.ctx, &"slots", {"uid": person})
	t.eq(e.send(&"day.end").get("err"), "must_resolve_pending", "ordinary consequences prompt")
	t.ok(bool(e.send(&"day.end", {"confirm": true}).get("ok")), "ordinary cards never deadlock")
	t.eq(CardPiles.zone_of(e.ctx, person), &"discard", "unhandled person leaves")
	t.eq(e.view()["open_panel"]["kind"], "", "end day closes panel")

static func _schedule(t: RefCounted) -> void:
	var e := H.engine(t)
	H.morning(t, e)
	var h := e.ctx.state.hash()
	t.ok(CardSchedule.due(e.ctx, 1).has("p.test.single"), "single day")
	t.ok(CardSchedule.due(e.ctx, 4).has("ev.test.window"), "window first Friday")
	t.ok(not CardSchedule.due(e.ctx, 5).has("ev.test.window"), "window only first match")
	t.ok(CardSchedule.due(e.ctx, 5).has("ev.test.when"), "condition first matching future day")
	t.ok(not CardSchedule.due(e.ctx, 6).has("ev.test.when"), "once future prediction selects first")
	t.ok(CardSchedule.due(e.ctx, 10).has("ev.test.repeat"), "non-once repeats")
	t.eq(CardSchedule.due(e.ctx, 0), PackedStringArray(), "past unavailable")
	t.eq(CardSchedule.due(e.ctx, 31), PackedStringArray(), "next stage unavailable")
	CardComposer.project(e.ctx, 4)
	t.eq(e.ctx.state.hash(), h, "schedule and projection read only")
	var scripted: Array = e.ctx.rules("deal").get("scripted_days", {}).get("0", [])
	for day in range(1, 31):
		var due := CardSchedule.due(e.ctx, day)
		if scripted.has(day):
			t.ok(not due.has("lf.test"), "life avoids scripted day")
	for _day in range(5):
		var forecast := CardSchedule.due(e.ctx, e.ctx.abs_day())
		e.send(&"day.begin")
		var defs: Array = []
		for uid in CardPiles.list(e.ctx, &"hand"): defs.append(CardPiles.card(e.ctx, uid)["def"])
		for id in forecast: t.ok(defs.has(id), "forecast card actually dealt %s" % id)
		e.send(&"day.end", {"confirm": true})
		e.send(&"night.choose", {"def": "nt.test.a"})
		e.send(&"settle.next")
	t.ok(e.ctx.state.ns("loop")["sched_done"].has("ev.test.when"), "scheduled once recorded")
	t.ok(not CardSchedule.due(e.ctx, 6).has("ev.test.when"), "once not re-dealt")
	_schedule_afternoon(t, e)

static func _schedule_afternoon(t: RefCounted, e: CardEngine) -> void:
	e.ctx.conds._conds[&"flag"]["fn"] = func(c: CardCtx, value: Variant) -> bool:
		return bool(c.state.ns("rules").get("flags", {}).get(str(value), false))
	e.send(&"day.begin")
	e.ctx.state.ns("rules")["flags"] = {"afternoon_ready": true}
	var next_day := e.ctx.abs_day() + 1
	var hash_before := e.state_hash()
	t.ok(CardSchedule.due(e.ctx, next_day).has("ev.test.afternoon"), "late-day condition predicts next unissued morning")
	t.eq(e.state_hash(), hash_before, "late-day forecast stays read only")
	e.send(&"day.end", {"confirm": true})
	e.send(&"night.choose", {"def": "nt.test.a"})
	e.send(&"settle.next")
	e.send(&"day.begin")
	t.ok(Array(CardPiles.list(e.ctx, &"hand")).any(func(uid: String) -> bool:
		return str(CardPiles.card(e.ctx, uid).get("def", "")) == "ev.test.afternoon"), "unchanged late-day condition really deals next morning")

static func _calendar(t: RefCounted) -> void:
	var e := H.engine(t)
	t.eq(CardCalendar.date_of(e.ctx, 1), {"y": 1938, "m": 3, "d": 1, "weekday": 1, "stage_day": 1}, "1938-03-01 Tuesday")
	t.eq(CardCalendar.date_of(e.ctx, 7)["weekday"], 0, "day7 Monday")
	for stage in range(3):
		e.ctx.state.ns("loop")["stage"] = stage
		var st := e.ctx.db.stage(stage)
		var date := CardCalendar.date_of(e.ctx, 1)
		t.eq("%04d-%02d-%02d" % [date["y"], date["m"], date["d"]], st["start"], "stage calendar start")
		for day in range(1, 31):
			t.eq(CardCalendar.is_market_day(e.ctx, day), posmod(day - 1 - int(st["market_offset"]), int(st["market_every"])) == 0, "market deterministic")
	for civil in [[1900, 3, 1], [2000, 2, 29], [1970, 1, 1], [1940, 2, 29]]:
		t.eq(CardCalendar.civil_from_days(CardCalendar.days_from_civil(civil[0], civil[1], civil[2])), civil, "civil round trip")

static func _goals(t: RefCounted) -> void:
	var e := H.engine(t)
	var goals: Array = e.view()["goals"]
	t.eq(goals.size(), 3, "one main two optional")
	t.eq(goals.filter(func(row: Dictionary) -> bool: return bool(row["main"])).size(), 1, "one main")
	t.eq(goals.map(func(row: Dictionary) -> String: return row["id"]).size(), 3, "selected goals")
	H.morning(t, e)
	CardGoals.evaluate(e.ctx, &"any_time")
	t.ok(e.ctx.test({"goal_status": ["gl.test.any", "open"]}), "any time initially open")
	e.ctx.state.ns("loop")["stage_day"] = 2
	CardGoals.evaluate(e.ctx, &"any_time")
	t.ok(e.ctx.test({"goal_status": ["gl.test.any", "done"]}), "any time done")
	var count := e.ctx.out.size()
	CardGoals.evaluate(e.ctx, &"any_time")
	t.eq(e.ctx.out.size(), count, "done effect once")
	e.ctx.state.ns("loop")["stage_day"] = 30
	CardGoals.evaluate(e.ctx, &"month_close")
	t.ok(e.ctx.test({"goal_status": ["gl.test.main", "done"]}), "main completed at month close")
	t.ok(e.ctx.test({"goal_status": ["gl.test.optional", "failed"]}), "unmet optional failed")
	t.eq(CardGoals.verdict_key(e.ctx), "g02.month.verdict.2", "verdict completed count tier")

static func _year(t: RefCounted) -> void:
	var e := H.engine(t)
	CardPiles.spawn(e.ctx, "ct.test.ma", &"contacts")
	var order: Array = []
	for priority in [50, 10, 30, 20]:
		e.ctx.hooks.on(&"year_jump", _record_priority.bind(order, priority), priority, "probe")
	t.ok(bool(CardYearJump.run(e.ctx).get("ok")), "year run")
	t.eq(order, [10, 20, 30, 50], "year hook priority order")
	t.ok(e.query(&"year_report")["lines"].any(func(row: Dictionary) -> bool: return row["key"] == "g02.year.contact"), "year person effect captured")
	var first: Dictionary = e.query(&"year_report")
	order.clear()
	CardYearJump.run(e.ctx)
	t.eq(e.query(&"year_report"), first, "same person year draw reproducible")

static func _record_priority(_ctx: CardCtx, _args: Dictionary, order: Array, priority: int) -> void:
	order.append(priority)

static func _save(t: RefCounted) -> void:
	var e := H.engine(t)
	var stage_path := CardSave.stage_path(0)
	t.ok(CardSave.exists(stage_path), "automatic stage save exists")
	var stage_contents := FileAccess.get_file_as_string(stage_path)
	H.morning(t, e)
	var resume_path := CardSave.suspend_path()
	var saved := CardSave.read(resume_path)
	t.eq(saved["cmd_log"], e.command_log(), "autosave includes triggering command")
	var h := H.without_resume(e.ctx.state)
	var v := e.view()
	e.send(&"ui.guide", {"step": "x", "status": "done"})
	t.ok(bool(e.load_game(resume_path).get("ok")), "load resume")
	t.eq(H.without_resume(e.ctx.state), h, "resume only adds resume first")
	t.eq(e.view(), v, "view stable after save load")
	t.eq(e.query(&"guide_progress")["progress"]["x"]["status"], "done", "ui memory union")
	t.ok(CardFirsts.all(e.ctx).has("resume"), "resume first marked")
	H.play_day(t, e)
	t.eq(FileAccess.get_file_as_string(stage_path), stage_contents, "day never overwrites stage snapshot")
	t.ok(bool(e.send(&"game.retry_stage").get("ok")), "retry stage")
	var retry_hash := e.ctx.state.hash()
	e.send(&"game.retry_stage")
	t.eq(e.ctx.state.hash(), retry_hash, "retry stable after first retry")
	t.eq(e.view()["phase"], "month_open", "retry at month open")
	var bad := e.ctx.state.hash()
	t.eq(e.save_game("").get("err"), "bad_args", "empty save path invalid")
	t.eq(e.ctx.state.hash(), bad, "bad save no state mutation")
	_save_migration(t, e)
	# Unknown loop fields survive read, and panels are re-emitted.
	e.ctx.state.ns("loop")["extension"] = {"n": 4}
	CardDayLoop.request_panel(e.ctx, &"slots", {"uid": "test"})
	var path: String = t.user_dir() + "/manual.json"
	e.save_game(path)
	var bus := CardEventBus.new()
	e.bus = bus
	var spy = t.spy(bus)
	e.load_game(path)
	t.eq(e.ctx.state.ns("loop")["extension"], {"n": 4}, "unknown fields preserved")
	t.eq(spy.count(&"request_panel"), 1, "load reopens panel")
	bus.free()

static func _save_migration(t: RefCounted, e: CardEngine) -> void:
	var old := CardState.from_dict(e.ctx.state.to_dict())
	old.ns("loop").erase("_v")
	old.ns("loop")["reports"] = {"settle": {}, "month": {}, "year": {}}
	old.ns("loop")["legacy_extension"] = 9
	var path: String = t.user_dir() + "/legacy.json"
	CardSave.write(path, old, {})
	t.ok(bool(e.load_game(path).get("ok")), "old loop schema migrates")
	t.eq(e.query(&"settle_report"), {"lines": []}, "old empty report normalized")
	t.eq(e.ctx.state.ns("loop")["legacy_extension"], 9, "unknown legacy key preserved")
	e.ctx.db._rules["loop"]["close_minute"] = int(e.ctx.db._rules["loop"]["close_minute"]) + 1
	t.ok(bool(e.load_game(path).get("meta", {}).get("db_changed", false)), "DB mismatch reads with notice metadata")
	var future := CardState.from_dict(e.ctx.state.to_dict())
	future.ns("loop")["_v"] = 2
	CardSave.write(path, future, {})
	var hash_before := e.state_hash()
	t.eq(e.load_game(path).get("err"), "save_newer", "newer loop version rejected")
	t.eq(e.state_hash(), hash_before, "newer save never replaces live state")

static func _determinism(t: RefCounted) -> void:
	for seed_value in range(10):
		var first := H.engine(t, seed_value)
		H.play_three(t, first)
		var h := first.ctx.state.hash()
		var second := H.engine(t, seed_value)
		H.play_three(t, second)
		t.eq(second.ctx.state.hash(), h, "same seed same instructions")
		var continuous := H.engine(t, seed_value)
		H.morning(t, continuous)
		H.play_day(t, continuous)
		var suspend_hash := H.without_resume(continuous.ctx.state)
		continuous.load_game(CardSave.suspend_path())
		t.eq(H.without_resume(continuous.ctx.state), suspend_hash, "morning reload deterministic")
		H.play_day(t, continuous)
		var replay := H.engine(t, seed_value)
		H.morning(t, replay)
		H.play_day(t, replay)
		H.play_day(t, replay)
		t.eq(H.without_resume(continuous.ctx.state), H.without_resume(replay.ctx.state), "save load continue equals uninterrupted")
		t.eq(t.find_floats(second.ctx.state.data), PackedStringArray(), "three stages no floats")

static func _month_open_once(t: RefCounted) -> void:
	var e := H.engine(t)
	t.eq(CardFirsts.all(e.ctx).get("month_open"), 0, "new game marks month_open once on day 0")
	var emitted := 0
	CardDayLoop.open_month(e.ctx)
	for event in e.ctx.out:
		if event[0] == &"first_time" and str(event[1]) == "month_open":
			emitted += 1
	t.eq(emitted, 0, "second open_month does not emit month_open")
	H.morning(t, e)
	t.eq(CardFirsts.all(e.ctx).get("month_open"), 0, "day 1 morning is not another month open")
	t.eq(e.view()["phase"], "morning", "day 1 left month_open")

static func _firsts(t: RefCounted) -> void:
	_month_open_once(t)
	var e := H.engine(t)
	var bus := CardEventBus.new()
	e.bus = bus
	var spy = t.spy(bus)
	H.play_three(t, e)
	e.send(&"game.retry_stage")
	e.send(&"game.retry_stage")
	e.load_game(CardSave.suspend_path())
	e.load_game(CardSave.suspend_path())
	e.send(&"game.retry_stage")
	e.load_game(CardSave.suspend_path())
	var names: Array = []
	for row in spy.log:
		if row[0] == &"first_time": names.append(str(row[1]))
	for name in ["notice", "gold", "night", "settle", "month_close", "year_jump", "game_over", "retry", "resume"]:
		t.eq(names.count(name), 1, "first once %s" % name)
	t.ok(not names.has("branch_pick"), "no reserved branch first")
	var guide_hash := e.ctx.state.hash()
	e.send(&"ui.guide", {"step": "x", "status": "shown"})
	t.eq(e.ctx.state.hash(), guide_hash, "guide does not affect game hash")
	bus.free()

static func _d1_3(t: RefCounted) -> void:
	var e := H.engine(t)
	var bus := CardEventBus.new()
	e.bus = bus
	var spy = t.spy(bus)
	H.morning(t, e)
	for _day in range(3):
		e.send(&"day.begin")
		e.send(&"day.end")
		e.send(&"day.end", {"confirm": true})
		e.send(&"night.choose", {"def": "nt.test.a"})
		e.send(&"settle.next")
	var by_day: Dictionary = {}
	for mechanism in CardFirsts.all(e.ctx).keys():
		var day := str(CardFirsts.all(e.ctx)[mechanism])
		if not by_day.has(day): by_day[day] = []
		by_day[day].append(mechanism)
	for day in by_day.keys(): by_day[day].sort()
	t.ok(by_day["1"].has("notice") and by_day["1"].has("night") and by_day["1"].has("settle"), "day1 first chain")
	t.ok(by_day["2"].has("gold") and by_day["2"].has("gold_leave"), "day2 gold chain")
	t.eq(CardFirsts.all(e.ctx).get("must_resolve"), 1, "day1 unresolved taught")
	print("G02 FIRSTS D1_3 " + JSON.stringify(by_day, "", true))
	bus.free()

