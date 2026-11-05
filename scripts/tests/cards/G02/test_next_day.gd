# 合同1.2：每个阶段推进、确认只记first、清单与实际后果一致、八步内换日和存读继续。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/G02/helpers.gd")

func _initialize() -> void:
	var t := T.new(self, "G02_next_day")
	_owned_consequences(t)
	_progress_all_phases(t)
	t.finish()

func _owned_consequences(t: RefCounted) -> void:
	var e := H.engine(t)
	H.morning(t, e)
	e.send(&"day.begin")
	for uid in CardPiles.list(e.ctx, &"hand"): CardPiles.move(e.ctx, uid, &"discard")
	var definitions := _definitions()
	var ids: Dictionary = {}
	for d in definitions:
		e.ctx.db._cards[d["id"]] = d
		ids[d["id"]] = CardPiles.spawn(e.ctx, d["id"], &"hand")
	var pending := CardPiles.spawn(e.ctx, "kp.test", &"pending", {"status": "overflow"})
	# An extension owns overflow and wait; the facade must preserve its row and hook ordering.
	e.ctx.mods.register(&"end_rows", func(_c: CardCtx, _a: Dictionary) -> Array:
		return [{"uid": pending, "def": "kp.test", "kind": "discard", "consequence_key": "g01.end.discard", "args": {}},
			{"uid": ids["kp.end.wait"], "def": "kp.end.wait", "kind": "wait", "consequence_key": "g01.end.wait", "args": {"days": 2}}], "probe")
	e.ctx.hooks.on(&"day_end", func(c: CardCtx, _a: Dictionary) -> void: CardPiles.discard(c, pending), 5, "probe")
	var bus := CardEventBus.new()
	e.bus = bus
	var spy = t.spy(bus)
	CardDayLoop.request_panel(e.ctx, &"kept_full", {"new_uid": pending})
	var before_view := e.view()
	var before_state := _without_firsts(e)
	var preview := e.query(&"day.end_preview")
	t.eq(_without_firsts(e), before_state, "preview reads without state mutation")
	t.no_leaks(preview)
	t.eq(preview["step"], "end_day", "day preview step")
	t.eq(preview["items"][-1]["uid"], pending, "pending panel follows all hand rows")
	t.eq(preview["items"].filter(func(row: Dictionary) -> bool: return row["kind"] == "wait").size(), 1, "wait extension remains")
	var rejected := e.send(&"day.end", {"confirm": false})
	t.eq(rejected.get("err"), "must_resolve_pending", "one confirmation error including gold")
	t.eq(rejected["items"], preview["items"], "rejected list matches preview")
	t.eq(e.view(), before_view, "unconfirmed command leaves view unchanged")
	t.eq(_without_firsts(e), before_state, "unconfirmed command changes only firsts")
	t.eq(CardFirsts.all(e.ctx).get("must_resolve"), 1, "must first before confirmation")
	t.eq(CardFirsts.all(e.ctx).get("gold_leave"), 1, "gold first before confirmation")
	var snapshot_path: String = t.user_dir() + "/end_snapshot.json"
	CardSave.write(snapshot_path, e.ctx.state, {})
	e.load_game(snapshot_path)
	t.eq(e.query(&"day.end_preview"), preview, "save restore same end preview")
	var result := e.send(&"day.end", {"confirm": true})
	t.ok(bool(result["ok"]), "overflow never intercepts confirmed day.end")
	t.eq(result["items"], preview["items"], "settlement returns exactly preview order")
	_assert_effects(t, e, spy, ids)
	e.send(&"day.end", {"confirm": true})
	var lines: Array = e.query(&"settle_report")["lines"]
	for row in preview["items"]:
		if row["kind"] not in ["wait", "pass"]:
			t.ok(lines.has({"key": row["consequence_key"], "args": row["args"]}), "each ignored consequence enters report")
	t.eq(spy.log.filter(func(ev: Array) -> bool: return ev[0] == &"first_time" and ev[1] == &"must_resolve").size(), 1, "must first once after save and confirm")
	t.eq(spy.log.filter(func(ev: Array) -> bool: return ev[0] == &"first_time" and ev[1] == &"gold_leave").size(), 1, "gold first once after save and confirm")
	bus.free()

func _assert_effects(t: RefCounted, e: CardEngine, spy: RefCounted, ids: Dictionary) -> void:
	var notices: Array = []
	for event in spy.log:
		if event[0] == &"notice": notices.append(event[1])
	t.eq(notices.count("end.person_expire"), 1, "person uses on_expire once")
	t.eq(notices.count("end.person_resolve"), 0, "person leave does not resolve")
	t.eq(notices.count("end.person_leave"), 0, "legacy on_leave ignored")
	t.eq(notices.count("end.absent_fail"), 1, "absent on_expire falls back to check.on_fail")
	t.eq(notices.count("end.empty_fail"), 0, "explicit empty on_expire suppresses check failure")
	t.eq(notices.count("end.pass_read"), 0, "unread passing news never executes on_read")
	for id in ids:
		if id == "kp.end.wait":
			t.eq(CardPiles.zone_of(e.ctx, ids[id]), &"hand", "keepable wait retained in hand")
		else:
			t.eq(CardPiles.zone_of(e.ctx, ids[id]), &"discard", "settled card leaves hand")
	var reasons := {"p.end.gold": &"gold_left", "p.end.person": &"left", "ev.end.absent": &"expired", "ev.end.empty": &"expired", "nw.end.pass": &"expired"}
	for id in reasons:
		t.ok(spy.log.has([&"card_left", ids[id], reasons[id]]), "card_left reason matches EndRow kind")

func _definitions() -> Array:
	return [
		{"id": "p.end.gold", "type": "person", "gold": true, "effects": {"on_expire": []}},
		{"id": "p.end.person", "type": "person", "effects": {"on_expire": [{"op": "notice", "key": "end.person_expire"}],
			"on_leave": [{"op": "notice", "key": "end.person_leave"}], "on_resolve": [{"op": "notice", "key": "end.person_resolve"}]}},
		{"id": "ev.end.absent", "type": "event", "check": {"on_fail": [{"op": "notice", "key": "end.absent_fail"}]}},
		{"id": "ev.end.empty", "type": "event", "effects": {"on_expire": []}, "check": {"on_fail": [{"op": "notice", "key": "end.empty_fail"}]}},
		{"id": "nw.end.pass", "type": "news", "must_resolve": false, "effects": {"on_read": [{"op": "notice", "key": "end.pass_read"}]}},
		{"id": "kp.end.wait", "type": "kept", "keepable": true, "must_resolve": false, "expires_days": 3}]

func _without_firsts(e: CardEngine) -> String:
	var copy := CardState.from_dict(e.ctx.state.to_dict())
	copy.ns("core")["firsts"] = {}
	return copy.hash()

func _progress_all_phases(t: RefCounted) -> void:
	var e := H.engine(t)
	var phases: Dictionary = {}
	var steps := 0
	var previous_day := e.ctx.abs_day()
	while e.view()["phase"] != "game_over" and steps < 400:
		var before_phase: String = e.view()["phase"]
		var before_day := e.ctx.abs_day()
		var preview := e.query(&"day.end_preview")
		var result := e.send(&"day.end", {"confirm": true})
		t.ok(bool(result.get("ok", false)), "every reachable phase advances: " + before_phase)
		t.eq(result["items"], preview["items"], "all phase previews match command")
		t.ok(before_phase != e.view()["phase"] or before_day < e.ctx.abs_day(), "confirmed command moves phase or day")
		phases[before_phase] = true
		steps += 1
		if e.ctx.abs_day() > previous_day:
			t.ok(steps <= CardIds.END_MAX_STEPS_TO_NEXT_DAY, "bounded steps to new day across month/year")
			previous_day = e.ctx.abs_day()
			steps = 0
		if before_phase == "year_jump":
			t.ok(CardSave.exists(CardSave.stage_path(int(e.view()["date"]["stage"]))), "day.end year writes stage snapshot")
		if e.view()["phase"] == "morning":
			t.eq(CardSave.read(CardSave.suspend_path())["meta"]["abs_day"], e.ctx.abs_day(), "day.end morning updates continuation save")
	t.eq(e.ctx.abs_day(), 90, "generic day.end completes ninety days")
	t.eq(phases.keys().size(), 7, "all seven reachable progression phases tested")
	t.ok(not CardFirsts.all(e.ctx).has("branch_pick"), "branch phase unreachable")
	t.eq(e.query(&"day.end_preview"), {"step": "", "needs_confirm": false, "items": []}, "game over preview empty")
	t.eq(e.send(&"day.end", {"confirm": true}).get("err"), "bad_phase", "game over rejects further advance")
	t.ok(bool(e.send(&"game.retry_stage").get("ok")), "game over can retry stage")
	t.eq(e.view()["phase"], "month_open", "retry restores month open")
	CardDayLoop.finish_game(e.ctx, "probe")
	t.ok(bool(e.send(&"game.load").get("ok")), "game over can load default continuation")
	t.eq(e.view()["phase"], "morning", "default load restores morning")
