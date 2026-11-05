# K18 pet real-flow (GPT 要改 #189)：真实 card.choose(search) 的 coin_check 成功/失败、
# 生产 retry_days 到期前后重排 + pending 去重精确计数、load 后真实找回不重发 first、
# 正式 gd.pet 在真引擎总线上完成。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Pet = preload("res://scripts/cards/rules/pet.gd")
const ARRIVE := "ev.1938.cat_arrive"
const FIND := "ev.1938.find_cat"
const STEP := "gd.pet"
const SEARCH_NEED := 1
const SEARCH_COINS := 2


func _initialize() -> void:
	var t := T.new(self, "K18_pet_flow")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	_find_coin_branches(t)
	_retry_days(t)
	_look_save_load_and_first(t)
	await _guide_hero(t)


func _boot(t, tag: String, seed_value: int, bus: CardEventBus = null) -> CardEngine:
	var engine: CardEngine = CardEngine.new(bus) if bus != null else CardEngine.new()
	var started: Dictionary = engine.new_game({
		"seed": seed_value,
		"only_examples": false,
		"save_dir": t.user_dir() + "/" + tag,
	})
	t.ok(bool(started.get("ok", false)), tag + " new_game")
	return engine


func _keep(t, engine: CardEngine, tag: String) -> String:
	var uid := CardPiles.spawn(engine.ctx, ARRIVE, &"hand")
	t.ok(uid != "", tag + " spawn arrive")
	var chosen: Dictionary = engine.send(&"card.choose", {"uid": uid, "choice": "keep"})
	t.ok(bool(chosen.get("ok", false)), tag + " keep: " + str(chosen.get("err", "")))
	t.ok(Pet.home(engine.ctx), tag + " home after keep")
	return uid


func _lose(ctx: CardCtx) -> void:
	ctx.state.ns("rules")["flags"]["pet_home"] = false
	ctx.state.ns("rules")["flags"]["pet_lost"] = true
	var bag: Dictionary = ctx.state.ns("rules")["pet"]
	bag["had"] = true
	bag["nights"] = 3
	bag["find_due"] = ctx.abs_day()


func _search_source(find_uid: String) -> String:
	# CardOps 给第 i 个效果接 /i；search 的 coin_check 是 effects[0]。
	return find_uid + "/choices/search/effects/0"


func _will_succeed(ctx: CardCtx, find_uid: String) -> bool:
	var source := _search_source(find_uid)
	var attempt := int(ctx.state.ns("rules").get("attempts", {}).get(source, 0))
	var faces: Array = CardCoins.toss(ctx, source, attempt, SEARCH_COINS)
	return faces.count(true) >= SEARCH_NEED


func _seed_for(t, want_success: bool, tag: String) -> Dictionary:
	# 可复现：扫种子，预测真 coin_check 分支后再正式 choose。
	for seed_value in range(1, 240):
		var bus := CardEventBus.new()
		root.add_child(bus)
		var engine := _boot(t, tag + "_scan_%d" % seed_value, seed_value, bus)
		_keep(t, engine, tag + "_scan")
		_lose(engine.ctx)
		var find_uid := CardPiles.spawn(engine.ctx, FIND, &"hand")
		if find_uid == "":
			bus.queue_free()
			continue
		if _will_succeed(engine.ctx, find_uid) == want_success:
			return {"seed": seed_value, "engine": engine, "bus": bus, "find_uid": find_uid}
		bus.queue_free()
	t.ok(false, tag + " no seed for want_success=" + str(want_success))
	return {}


func _notices(spy) -> Array:
	var out: Array = []
	for row in spy.log:
		if row[0] == &"notice":
			out.append(str(row[1]))
	return out


func _card_left(spy, uid: String) -> bool:
	for row in spy.log:
		if row[0] == &"card_left" and str(row[1]) == uid:
			return true
	return false


func _find_coin_branches(t) -> void:
	var ok_pack: Dictionary = _seed_for(t, true, "find_ok")
	if ok_pack.is_empty():
		return
	var ok_engine: CardEngine = ok_pack["engine"]
	var ok_bus: CardEventBus = ok_pack["bus"]
	var ok_spy = t.spy(ok_bus)
	var find_ok: String = str(ok_pack["find_uid"])
	t.ok(_will_succeed(ok_engine.ctx, find_ok), "find_ok seed predicts success")
	ok_spy.clear()
	var searched_ok: Dictionary = ok_engine.send(&"card.choose", {"uid": find_ok, "choice": "search"})
	t.ok(bool(searched_ok.get("ok", false)), "find_ok search: " + str(searched_ok.get("err", "")))
	t.ok(Pet.home(ok_engine.ctx), "find_ok home restored via coin_check then")
	t.ok(not bool(ok_engine.ctx.state.ns("rules").get("flags", {}).get("pet_lost", false)), "find_ok not lost")
	t.ok(_notices(ok_spy).has("k18.notice.found"), "find_ok notice found")
	t.ok(_card_left(ok_spy, find_ok), "find_ok card left hand")
	t.eq(ok_engine.view().get("pet", {}), {"show": true, "home": true, "lost": false}, "find_ok plaque")
	t.ok(not _find_queued(ok_engine.ctx), "find_ok no find queued after success")
	_assert_day_advances(t, ok_engine, "find_ok")
	ok_bus.queue_free()

	var fail_pack: Dictionary = _seed_for(t, false, "find_fail")
	if fail_pack.is_empty():
		return
	var fail_engine: CardEngine = fail_pack["engine"]
	var fail_bus: CardEventBus = fail_pack["bus"]
	var fail_spy = t.spy(fail_bus)
	var find_fail: String = str(fail_pack["find_uid"])
	t.ok(not _will_succeed(fail_engine.ctx, find_fail), "find_fail seed predicts failure")
	fail_spy.clear()
	var searched_fail: Dictionary = fail_engine.send(&"card.choose", {"uid": find_fail, "choice": "search"})
	t.ok(bool(searched_fail.get("ok", false)), "find_fail search: " + str(searched_fail.get("err", "")))
	t.ok(not Pet.home(fail_engine.ctx), "find_fail still not home")
	t.ok(bool(fail_engine.ctx.state.ns("rules").get("flags", {}).get("pet_lost", false)), "find_fail still lost")
	t.ok(_notices(fail_spy).has("k18.notice.still_lost"), "find_fail notice still_lost")
	t.ok(_card_left(fail_spy, find_fail), "find_fail card left hand")
	# 失败后清掉可能已入队的找猫，交给生产 retry_days 路径验证。
	_clear_find(fail_engine.ctx)
	_assert_day_advances(t, fail_engine, "find_fail")
	fail_bus.queue_free()

	var leave_engine := _boot(t, "find_leave", 13)
	_keep(t, leave_engine, "find_leave")
	_lose(leave_engine.ctx)
	var find_leave := CardPiles.spawn(leave_engine.ctx, FIND, &"hand")
	var left: Dictionary = leave_engine.send(&"card.choose", {"uid": find_leave, "choice": "leave_it"})
	t.ok(bool(left.get("ok", false)), "leave_it: " + str(left.get("err", "")))
	t.ok(not Pet.home(leave_engine.ctx), "leave_it not home")
	t.ok(bool(leave_engine.ctx.state.ns("rules").get("flags", {}).get("pet_lost", false)), "leave_it still lost")
	_clear_find(leave_engine.ctx)
	_assert_day_advances(t, leave_engine, "find_leave")


func _retry_days(t) -> void:
	# 生产 retry_days：到期前不排，到期后排一次；有待处理找猫时走 _find_pending 去重（不把 find_due 改成当天）。
	var engine := _boot(t, "retry", 19)
	_keep(t, engine, "retry")
	_lose(engine.ctx)
	_clear_find(engine.ctx)
	var retry := maxi(1, int(engine.ctx.rules("pet").get("retry_days", 3)))
	var bag: Dictionary = engine.ctx.state.ns("rules")["pet"]
	var today := engine.ctx.abs_day()
	bag["find_due"] = today + retry
	Pet.on_night(engine.ctx, {})
	t.ok(not _find_queued(engine.ctx), "retry: before due does not queue")
	engine.ctx.state.ns("loop")["abs_day"] = today + retry - 1
	Pet.on_night(engine.ctx, {})
	t.ok(not _find_queued(engine.ctx), "retry: day before due still does not queue")
	engine.ctx.state.ns("loop")["abs_day"] = today + retry
	Pet.on_night(engine.ctx, {})
	t.eq(_find_count(engine.ctx), 1, "retry: on due queues exactly one FIND")
	var due_after := int(engine.ctx.state.ns("rules")["pet"].get("find_due", -1))
	t.eq(due_after, today + retry + retry, "retry: find_due advances by retry_days")
	var queued_day := _find_queue_abs_day(engine.ctx)
	t.eq(queued_day, today + retry + retry, "retry: queue abs_day is due+retry_days")
	# 保留队列，推进到新的 find_due，再 on_night → 命中 _find_pending 去重，不得再入队。
	engine.ctx.state.ns("loop")["abs_day"] = due_after
	Pet.on_night(engine.ctx, {})
	t.eq(_find_count(engine.ctx), 1, "retry: pending FIND dedupes; still exactly one")
	t.eq(_find_queue_abs_day(engine.ctx), queued_day, "retry: queue abs_day unchanged after dedupe night")
	t.eq(int(engine.ctx.state.ns("rules")["pet"].get("find_due", -1)), due_after, "retry: find_due unchanged while pending")
	# 清掉后再夜：把 find_due 推到未来，确认未到期不排
	_clear_find(engine.ctx)
	engine.ctx.state.ns("rules")["pet"]["find_due"] = engine.ctx.abs_day() + retry
	Pet.on_night(engine.ctx, {})
	t.ok(not _find_queued(engine.ctx), "retry: after clear, before new due does not queue")


func _look_save_load_and_first(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var spy = t.spy(bus)
	var engine := _boot(t, "look", 7, bus)
	spy.clear()
	_keep(t, engine, "look")
	var pet_firsts := 0
	for row in spy.log:
		if row[0] == &"first_time" and str(row[1]) == "pet":
			pet_firsts += 1
	t.eq(pet_firsts, 1, "first pet fires exactly once on keep")
	var ctx := engine.ctx
	Pet._morning(ctx, {})
	t.eq(int(ctx.state.ns("rules")["pet"].get("look_left", 0)), 1, "look granted morning")
	var spot: Dictionary = CardAppraisal.params_for(ctx, "", &"spot")
	# 10-25 appraisal redesign: base ink comes from the eye aids; the cat's look adds one.
	t.eq(int(spot.get("ink", -1)), int(CardAppraisal._aids(ctx, &"spot", "")["ink"]) + 1, "look spends on spot")
	t.eq(int(ctx.state.ns("rules")["pet"].get("look_left", 0)), 0, "look spent")
	Pet._morning(ctx, {})
	t.eq(int(ctx.state.ns("rules")["pet"].get("look_left", 0)), 0, "same-day morning does not refill")
	ctx.state.ns("loop")["abs_day"] = ctx.abs_day() + 1
	Pet._morning(ctx, {})
	t.eq(int(ctx.state.ns("rules")["pet"].get("look_left", 0)), 1, "next day look refill")
	# 再次 keep / 找回不得再发 first pet
	spy.clear()
	var again := CardPiles.spawn(ctx, ARRIVE, &"hand")
	engine.send(&"card.choose", {"uid": again, "choice": "keep"})
	pet_firsts = 0
	for row in spy.log:
		if row[0] == &"first_time" and str(row[1]) == "pet":
			pet_firsts += 1
	t.eq(pet_firsts, 0, "second keep does not re-fire first pet")
	var path: String = t.user_dir() + "/look/mid.json"
	t.ok(bool(engine.send(&"game.save", {"path": path}).get("ok", false)), "save")
	var bus2 := CardEventBus.new()
	root.add_child(bus2)
	var spy2 = t.spy(bus2)
	var loaded := CardEngine.new(bus2)
	t.ok(bool(loaded.load_game(path).get("ok", false)), "load")
	t.ok(Pet.home(loaded.ctx), "home after load")
	t.ok(CardFirsts.all(loaded.ctx).has("pet"), "first survives load")
	# 保留 load 期间 spy：不得在 load 时重发 pet first。
	pet_firsts = 0
	for row in spy2.log:
		if row[0] == &"first_time" and str(row[1]) == "pet":
			pet_firsts += 1
	t.eq(pet_firsts, 0, "load itself does not re-fire first pet")
	# 真实找回：走丢后扫确定性成功分支，实际 card.choose(search)。
	_lose(loaded.ctx)
	_clear_find(loaded.ctx)
	var find_ok_uid := ""
	for _i in range(48):
		var cand := CardPiles.spawn(loaded.ctx, FIND, &"hand")
		if cand == "":
			continue
		if _will_succeed(loaded.ctx, cand):
			find_ok_uid = cand
			break
		CardPiles.resolve(loaded.ctx, cand, &"resolved")
	t.ok(find_ok_uid != "", "loaded find: found deterministic success uid")
	t.ok(_will_succeed(loaded.ctx, find_ok_uid), "loaded find: predicts success")
	var searched_loaded: Dictionary = loaded.send(&"card.choose", {"uid": find_ok_uid, "choice": "search"})
	t.ok(bool(searched_loaded.get("ok", false)), "loaded find search: " + str(searched_loaded.get("err", "")))
	t.ok(Pet.home(loaded.ctx), "loaded find restores home")
	t.ok(not bool(loaded.ctx.state.ns("rules").get("flags", {}).get("pet_lost", false)), "loaded find clears lost")
	pet_firsts = 0
	for row in spy2.log:
		if row[0] == &"first_time" and str(row[1]) == "pet":
			pet_firsts += 1
	t.eq(pet_firsts, 0, "real find after load does not re-fire first pet")
	t.eq(int(loaded.ctx.state.ns("rules")["pet"].get("look_left", -1)), 1, "look_left survives load")
	t.eq(loaded.view().get("pet", {}), {"show": true, "home": true, "lost": false}, "plaque after load find")
	_assert_day_advances(t, loaded, "look_loaded")
	bus.queue_free()
	bus2.queue_free()


func _guide_hero(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var engine := _boot(t, "guide", 7, bus)
	_keep(t, engine, "guide")
	_to_day(t, engine, "guide")
	var bar: CardHeroBar = load("res://scenes/cards/card/HeroBar.tscn").instantiate()
	root.add_child(bar)
	await t.frames(1)
	bar.refresh(engine.view())
	await t.frames(1)
	t.ok(t.anchor_ok(&"a.pet"), "HeroBar registers a.pet")
	var plaque := bar.get_node_or_null("PetPlaque") as CanvasItem
	t.ok(plaque != null and plaque.visible, "pet plaque visible on HeroBar")
	var guide: CardGuide = load("res://scenes/cards/shell/GuideOverlay.tscn").instantiate()
	guide.skip_fades = true
	root.add_child(guide)
	# 真引擎总线：keep 时已发 first pet；bind 后补进 guide 记忆并点亮。
	guide.bind(engine, bus)
	var raw: Dictionary = CardDB.read_json("res://data/cards/guide/steps.json")
	var pet_step: Dictionary = {}
	for row in raw.get("cards", []):
		if str(row.get("id", "")) == STEP:
			pet_step = row
			break
	t.ok(not pet_step.is_empty(), "formal gd.pet in steps.json")
	t.eq(str(pet_step.get("anchor", "")), "a.pet", "formal step anchors a.pet")
	guide.load_steps({"steps": [pet_step], "pages": [], "settings": {"max_new_per_day": 8, "gap_ms": 0, "default_seconds": 30}})
	guide.force(true)
	# 补记 first（引擎在 bind 前已发过）；不手工 emit 到别的总线。
	guide._on_first(&"pet", {"uid": "kept", "def": ARRIVE})
	guide.evaluate_now()
	t.eq(guide.active_step(), STEP, "gd.pet lights on day phase")
	t.eq(str(guide._anchor_now), "a.pet", "gd.pet anchors a.pet")
	var before := engine.ctx.abs_day()
	var ended: Dictionary = engine.send(&"day.end", {"confirm": true})
	t.ok(bool(ended.get("ok", false)), "day.end while guide lit: " + str(ended.get("err", "")))
	# done_when: cmd:day.end —— 需处理 deferred / evaluate
	guide.evaluate_now()
	await t.frames(2)
	guide.evaluate_now()
	t.eq(guide.active_step(), "", "gd.pet exits after day.end done_when")
	var prog: Dictionary = engine.query(&"guide_progress").get("progress", {})
	var row: Dictionary = prog.get(STEP, {})
	t.eq(str(row.get("status", "")), "done", "guide_progress gd.pet done")
	_assert_day_advances(t, engine, "guide_day")
	t.ok(engine.ctx.abs_day() >= before, "abs_day not stuck under guide")
	guide.queue_free()
	bar.queue_free()
	bus.queue_free()
	await t.frames(1)


func _to_day(t, engine: CardEngine, tag: String) -> void:
	var guard := 0
	while str(engine.view().get("phase", "")) != "day" and str(engine.view().get("phase", "")) != "game_over" and guard < 12:
		guard += 1
		var phase := str(engine.view().get("phase", ""))
		if phase in ["month_open", "morning", "night", "settle", "month_close", "year_jump"]:
			var step: Dictionary = engine.send(&"day.end", {"confirm": true})
			if not bool(step.get("ok", false)) and phase == "morning":
				step = engine.send(&"day.begin", {})
			t.ok(bool(step.get("ok", false)) or str(engine.view().get("phase", "")) == "day",
				tag + " advance from " + phase + ": " + str(step.get("err", "")))
		elif phase == "day":
			break
		else:
			var begin: Dictionary = engine.send(&"day.begin", {})
			if not bool(begin.get("ok", false)):
				engine.send(&"day.end", {"confirm": true})
	t.eq(str(engine.view().get("phase", "")), "day", tag + " reached day")


func _assert_day_advances(t, engine: CardEngine, tag: String) -> void:
	var today := engine.ctx.abs_day()
	var guard := 0
	while engine.ctx.abs_day() == today and str(engine.view().get("phase", "")) != "game_over" and guard < 8:
		guard += 1
		var step: Dictionary = engine.send(&"day.end", {"confirm": true})
		t.ok(bool(step.get("ok", false)), tag + " day.end: " + str(step.get("err", "")))
		if not bool(step.get("ok", false)):
			break
	var over := str(engine.view().get("phase", "")) == "game_over"
	t.ok(engine.ctx.abs_day() > today or over, tag + " abs_day advanced or game_over")


func _find_count(ctx: CardCtx) -> int:
	var n := 0
	for row in ctx.state.ns("core").get("queue", []):
		if typeof(row) == TYPE_DICTIONARY and str(row.get("def", "")) == FIND:
			n += 1
	for uid in CardPiles.list(ctx, &"hand"):
		if str(CardPiles.card(ctx, uid).get("def", "")) == FIND:
			n += 1
	for uid in CardPiles.list(ctx, &"kept"):
		if str(CardPiles.card(ctx, uid).get("def", "")) == FIND:
			n += 1
	return n


func _find_queue_abs_day(ctx: CardCtx) -> int:
	for row in ctx.state.ns("core").get("queue", []):
		if typeof(row) == TYPE_DICTIONARY and str(row.get("def", "")) == FIND:
			return int(row.get("abs_day", -1))
	return -1


func _find_queued(ctx: CardCtx) -> bool:
	return _find_count(ctx) > 0


func _clear_find(ctx: CardCtx) -> void:
	var q: Array = ctx.state.ns("core").get("queue", [])
	var keep: Array = []
	for row in q:
		if typeof(row) == TYPE_DICTIONARY and str(row.get("def", "")) == FIND:
			continue
		keep.append(row)
	ctx.state.ns("core")["queue"] = keep
	for uid in CardPiles.list(ctx, &"hand"):
		if str(CardPiles.card(ctx, uid).get("def", "")) == FIND:
			CardPiles.resolve(ctx, uid, &"resolved")
