# W0 骨架自测⑤：打烊 · 下一天永远可用、绝不卡住（主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”）。
# 对 Mock 情景模式查：① 每个阶段 day.end {confirm:true} 都往前走（game_over 除外，那里 game.retry_stage 能走）；
# ② 预览 day.end_preview 和确认后真结算的是同一张清单，没确认时只记 first、视图不变；③ 牢房连续 3 晚没出来按打点失败；
# ④ 随机乱点 + 随机打烊跑 300 局，从任何状态连按最多 END_MAX_STEPS_TO_NEXT_DAY 次打烊，天数一定往前走（或局终）；
# ⑤ 牌桌上的“打烊”按钮：要确认时开 end_day 面板、确认才发 day.end {confirm:true}；面板的“算了”；局终时按钮开局终面板；
# ⑥ 十个基础夹具各按一次按钮（要确认的开 end_day、不用确认的直接往前走）；⑦ 每种面板 Esc 都关得掉、该发的“算了”指令发了。
# 合同：docs/cards/CARDS_INTERFACES.md §7.4.7、§7.7、§7.8。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Scenario = preload("res://scripts/cards/mock/mock_scenario.gd")
const FUZZ_RUNS := 300
const FUZZ_DAYS := 6


func _initialize() -> void:
	var t := T.new(self, "W0_next_day")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var db := CardDB.load_all(CardDB.DEFAULT_ROOT, {"only_examples": true})
	CardText.setup(db)
	_check_phases(t, db)
	_check_preview_matches(t, db)
	_check_prison(t, db)
	_fuzz(t, db)
	await _check_table(t)


## ① 每个阶段都往前走
func _check_phases(t, db: CardDB) -> void:
	var scn = Scenario.new(db, {"seed": 7})
	scn.start()
	var seen: Dictionary = {}
	var guard := 0
	while str(scn.st["phase"]) != "game_over" and guard < 400:
		guard += 1
		var before := _pos(scn)
		var r: Dictionary = scn.send("day.end", {"confirm": true})
		t.ok(bool(r.get("ok", false)), "day.end ok in %s (%s)" % [before, r.get("err", "")])
		t.ok(_pos(scn) != before, "day.end moved on from %s" % before)
		seen[str(r.get("step", ""))] = true
		if int(scn.st["stage"]) >= 1 and str(scn.st["phase"]) == "morning":
			break
	for s in CardIds.END_STEPS:
		t.ok(seen.has(str(s)), "step %s was taken" % s)
	t.ok(guard < 400, "a whole stage by pressing next-day only (%d presses)" % guard)
	scn.st["phase"] = "game_over"
	t.eq(scn.send("day.end", {"confirm": true}).get("err"), "bad_phase", "game_over: day.end refused")
	t.eq(scn.query("day.end_preview", {}).get("step"), "", "game_over: preview has no step")
	t.ok(bool(scn.send("game.retry_stage", {}).get("ok", false)), "game_over: retry works")
	t.eq(str(scn.st["phase"]), "month_open", "retry goes back to month_open")


## ② 预览 = 结算；没确认只记 first
func _check_preview_matches(t, db: CardDB) -> void:
	var scn = Scenario.new(db, {"seed": 7})
	scn.start()
	scn.setup_day_full()
	var pv: Dictionary = scn.query("day.end_preview", {})
	t.no_leaks(pv, "day.end_preview")
	t.ok(bool(pv["needs_confirm"]), "day_full needs a confirm")
	var view_before = scn.view()
	var r: Dictionary = scn.send("day.end", {"confirm": false})
	t.eq(r.get("err"), CardIds.ERR_MUST_RESOLVE, "confirm:false -> must_resolve_pending")
	t.eq(r.get("items"), pv["items"], "result items == preview items")
	t.eq(scn.view(), view_before, "confirm:false changes nothing visible")
	var firsts: Array = scn.events.filter(func(e: Array) -> bool: return e[0] == "first_time").map(
		func(e: Array) -> String: return str(e[1]))
	t.eq(firsts, ["gold_leave", "must_resolve"], "first gold_leave and must_resolve before the confirm")
	r = scn.send("day.end", {"confirm": true})
	t.ok(bool(r.get("ok", false)), "confirm:true ok")
	t.eq(str(scn.st["phase"]), "night", "into the night")
	var left: Dictionary = {}
	for e in scn.events:
		if e[0] == "card_left":
			left[str(e[1])] = str(e[2])
	var want_reason := {"gold_leave": "gold_left", "leave": "left", "ignore": "expired", "pass": "expired",
		"void": "expired"}
	for it in pv["items"]:
		var k := str(it["kind"])
		t.ok(CardIds.END_KINDS.has(StringName(k)), "known kind " + k)
		if want_reason.has(k):
			t.eq(left.get(str(it["uid"]), ""), want_reason[k], "%s %s left as %s" % [k, it["def"], want_reason[k]])
		elif str(it["uid"]) != "":
			t.ok(not left.has(str(it["uid"])), "%s %s stays" % [k, it["def"]])
	for e in scn.events:
		t.no_leaks(e, "event " + str(e[0]))


## ③ 牢房：没处理就多待一晚；连续 PRISON_MAX_DAYS 晚没出来按打点失败；第二天不发人物牌
func _check_prison(t, db: CardDB) -> void:
	var scn = Scenario.new(db, {"seed": 7})
	scn.start()
	scn.setup_street_prison()
	var nights := 0
	var guard := 0
	while str(scn.st["phase"]) != "game_over" and guard < 40:
		guard += 1
		if str(scn.st["phase"]) == "day":
			var pv: Dictionary = scn.query("day.end_preview", {})
			var row: Array = pv["items"].filter(func(i: Dictionary) -> bool: return str(i["def"]) == "pr.cell")
			t.eq(row.size(), 1, "prison row in the list")
			if not row.is_empty():
				nights += 1
				t.eq(str(row[0]["kind"]), "fail" if nights >= Scenario.PRISON_MAX_DAYS else "stay", "night %d" % nights)
				t.eq(int(row[0]["args"]["nights"]), nights, "nights counted")
			if nights >= 2:
				for c in scn.view()["hand"]:
					t.ok(str(c["type"]) != "person" or str(c["def"]) == "pr.cell", "in jail: no person cards dealt")
		scn.send("day.end", {"confirm": true})
	t.eq(str(scn.st["phase"]), "game_over", "prison: game over after the last night")
	t.eq(nights, Scenario.PRISON_MAX_DAYS, "game over on night %d" % Scenario.PRISON_MAX_DAYS)
	t.eq(str(scn.st["game_over"]), "prison", "reason prison")


## ④ 乱点 + 随机打烊：不卡死
func _fuzz(t, db: CardDB) -> void:
	var stuck := 0
	var bad_end := 0
	for run in range(1, FUZZ_RUNS + 1):
		var scn = Scenario.new(db, {"seed": run})
		scn.start()
		var steps := 0
		while steps < 400 and int(scn.st["abs_day"]) < FUZZ_DAYS and str(scn.st["phase"]) != "game_over":
			steps += 1
			var u := JevRng.draw(run, "c.mock", ["fuzz", steps])
			if u < 0.15:
				var confirm := JevRng.draw(run, "c.mock", ["fuzz_confirm", steps]) < 0.7
				var r: Dictionary = scn.send("day.end", {"confirm": confirm})
				if not bool(r.get("ok", false)) and not (not confirm and str(r.get("err", "")) == CardIds.ERR_MUST_RESOLVE):
					bad_end += 1
			else:
				var a := _random_action(scn, run, steps)
				scn.send(str(a[0]), a[1])
			if steps % 25 == 0 and not _escapes(scn):
				stuck += 1
		if not _escapes(scn):
			stuck += 1
	t.eq(bad_end, 0, "day.end never refused outside game_over (%d runs)" % FUZZ_RUNS)
	t.eq(stuck, 0, "from every visited state next-day presses reach a new day (%d runs)" % FUZZ_RUNS)


## 连按打烊：最多 END_MAX_STEPS_TO_NEXT_DAY 次，天数变大或局终
func _escapes(scn) -> bool:
	if str(scn.st["phase"]) == "game_over":
		return true
	var day0 := int(scn.st["abs_day"])
	for i in range(CardIds.END_MAX_STEPS_TO_NEXT_DAY):
		var r: Dictionary = scn.send("day.end", {"confirm": true})
		if not bool(r.get("ok", false)):
			return false
		if int(scn.st["abs_day"]) > day0 or str(scn.st["phase"]) == "game_over":
			return true
	return false


func _random_action(scn, run: int, step: int) -> Array:
	var v: Dictionary = scn.view()
	var pick := func(n: int, salt: String) -> int: return int(JevRng.draw(run, "c.mock", [salt, step]) * n)
	match str(v["phase"]):
		"month_open":
			return [["wheel.offer", {"wheel": "wh.month", "uid": "", "source": {"kind": "money", "amount": 5}}],
				["wheel.spin", {"wheel": "wh.month", "uid": ""}], ["month.begin", {}]][pick.call(3, "mo")]
		"morning":
			return ["day.begin", {}]
		"night":
			var offers: Array = v["night_offers"]
			return ["night.choose", {"def": str(offers[pick.call(offers.size(), "nt")]) if not offers.is_empty() else ""}]
		"settle":
			return ["settle.next", {}]
		"month_close":
			return ["month.next", {}]
		"year_jump":
			return ["year.next", {}]
		"day":
			var hand: Array = v["hand"]
			if hand.is_empty():
				return ["card.keep", {"uid": "c9999"}]
			var c: Dictionary = hand[pick.call(hand.size(), "card")]
			var uid := str(c["uid"])
			var cmds := [["counter.open", {"uid": uid}], ["counter.offer", {"uid": uid, "tier": "fair"}],
				["counter.offer", {"uid": uid, "tier": "harsh"}], ["counter.refuse", {"uid": uid}],
				["counter.close", {"uid": uid}], ["card.keep", {"uid": uid}], ["card.read", {"uid": uid}],
				["slot.place", {"uid": uid, "slot": "man", "source": {"kind": "self"}}], ["slot.roll", {"uid": uid}],
				["card.choose", {"uid": uid, "choice": "listen"}], ["fortune.lot", {"uid": uid}],
				["counter.pick_stock", {"uid": uid, "item": "I001"}], ["no.such", {"x": 1}]]
			return cmds[pick.call(cmds.size(), "cmd")]
	return ["no.such", {}]


## ⑤ 牌桌：打烊按钮开确认面板；确认才发 day.end {confirm:true}；夜牌面板的“算了”= 今晚不选
func _check_table(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true, "bus": bus, "fixture": "day_full", "skip_title": true})
	root.add_child(game)
	await t.frames(2)
	var mock: MockCardEngine = game.engine
	game._on_close_day()
	await t.frames(1)
	t.eq(game.host.top_kind(), &"end_day", "next-day with unresolved cards opens the confirm panel")
	t.eq(mock.sent.back(), ["day.end", {"confirm": false}], "the button first asks with confirm:false")
	game.host.top_panel().autoplay_step()
	await t.frames(1)
	t.eq(mock.sent.back(), ["day.end", {"confirm": true}], "confirming sends day.end {confirm:true}")
	t.eq(game.engine.view().get("phase"), "night", "confirmed: into the night")
	game.queue_free()
	await t.frames(2)
	var game2: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game2.boot({"mock": true, "bus": bus, "seed": 7, "skip_title": true, "guide": "off"})
	root.add_child(game2)
	await t.frames(2)
	var guard := 0
	while str(game2.engine.view().get("phase", "")) != "night" and guard < 200:
		guard += 1
		game2.autoplay_step()
		await t.frames(1)
	t.eq(str(game2.engine.view().get("phase", "")), "night", "autoplay reaches the first night")
	if game2.host.top_kind() != &"night":
		game2.host.open_panel(&"night", {})
	game2.host.close_top()
	await t.frames(1)
	var mock2: MockCardEngine = game2.engine
	t.eq(mock2.sent.back(), ["night.choose", {"def": ""}], "Esc on the night panel = tonight choose nothing")
	t.eq(str(game2.engine.view().get("phase", "")), "settle", "then the day settles")
	# 局终：day.end 不走，按钮改开局终面板；局终面板的“算了”= 回标题（关得掉）
	await _close_all(game2)
	mock2._scn.st["phase"] = "game_over"
	game2._sync_phase_panel()   # 局终面板自动开一次（和别的阶段面板一样），玩家把它关了
	await t.frames(1)
	t.eq(game2.host.top_kind(), &"game_over", "game_over: the panel opens once by itself")
	await _close_all(game2)
	game2._on_close_day()
	await t.frames(1)
	t.eq(game2.host.top_kind(), &"game_over", "game_over: the next-day button opens the game-over panel")
	game2.host.close_top()
	await t.frames(1)
	t.ok(game2.host.top_panel() == null, "game_over panel closes with Esc")
	game2.queue_free()
	await t.frames(2)
	await _check_fixture_buttons(t, bus)
	await _check_every_panel_closes(t, bus)
	bus.queue_free()
	await t.frames(2)


## ⑥ 十个基础夹具各按一次“打烊 · 下一天”：要确认的开 end_day（确认后往前走），不用确认的直接往前走
func _check_fixture_buttons(t, bus: CardEventBus) -> void:
	for fx in ["month_open", "month_wheel", "morning", "day_full", "day_counter", "night", "settle", "month_close",
			"year_jump", "street_prison"]:
		var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
		game.boot({"mock": true, "bus": bus, "fixture": fx, "skip_title": true})
		root.add_child(game)
		await t.frames(2)
		await _close_all(game)
		var mock: MockCardEngine = game.engine
		var pv: Dictionary = mock.query(&"day.end_preview")
		var before := _vpos(mock.view())
		game._on_close_day()
		await t.frames(1)
		t.eq(mock.sent.back(), ["day.end", {"confirm": false}], "%s: the button asks with confirm:false" % fx)
		if bool(pv.get("needs_confirm", false)):
			t.eq(game.host.top_kind(), &"end_day", "%s: unresolved things -> confirm panel" % fx)
			t.eq(_vpos(mock.view()), before, "%s: nothing moves before the confirm" % fx)
			if game.host.top_kind() == &"end_day":
				game.host.top_panel().autoplay_step()
				await t.frames(1)
				t.eq(mock.sent.back(), ["day.end", {"confirm": true}], "%s: confirm sends confirm:true" % fx)
		t.ok(_vpos(mock.view()) != before, "%s: next-day moved on from %s" % [fx, before])
		game.queue_free()
		await t.frames(2)


## ⑦ 每种面板开着时 Esc（宿主调 dismiss()）都关得掉；有默认做法的先发那条指令（合同 §7.8）
func _check_every_panel_closes(t, bus: CardEventBus) -> void:
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true, "bus": bus, "fixture": "day_full", "skip_title": true})
	root.add_child(game)
	await t.frames(2)
	await _close_all(game)
	var mock: MockCardEngine = game.engine
	var want := {&"counter": "counter.close", &"kept_full": "card.discard", &"contacts_full": "contact.release",
		&"short": "short.resolve"}
	for kind in CardIds.PANELS:
		if kind == &"minigame":
			continue
		var n := mock.sent.size()
		game.host.open_panel(kind, {"uid": "c0005", "new_uid": "c0010", "source": "c0005"})
		await t.frames(1)
		game.host.close_top()
		await t.frames(1)
		t.ok(game.host.top_panel() == null, "%s: Esc closes it, back to the table" % kind)
		if want.has(kind):
			t.eq(str(mock.sent.back()[0]) if mock.sent.size() > n else "", want[kind], "%s: Esc sends its default" % kind)
		else:
			t.eq(mock.sent.size(), n, "%s: Esc sends nothing" % kind)
		await _close_all(game)
	game.queue_free()
	await t.frames(2)


func _close_all(game: CardGameRoot) -> void:
	var guard := 0
	while game.host.top_panel() != null and guard < 10:
		guard += 1
		game.host.close_panel(game.host.top_panel())
		await process_frame


func _vpos(v: Dictionary) -> String:
	return "%s/%d/%d" % [v.get("phase", ""), int(v.get("date", {}).get("stage", 0)), int(v.get("date", {}).get("abs_day", 0))]


func _pos(scn) -> String:
	return "%s/%d/%d" % [scn.st["phase"], int(scn.st["stage"]), int(scn.st["abs_day"])]
