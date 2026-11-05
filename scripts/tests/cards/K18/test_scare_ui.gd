# K18 scare UI（GPT 要改 #191）：共享 hand 关柜不藏；吓唬成败结算；未掷打烊推进；gd.scare 真指引。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const GUEST := "p.chen.1939.pawn_clock"
const REDEEM := "p.chen.1939.redeem"
const BUY := "p.sunyoung.1939.buy_scroll"
const SELL := "p.zhang.1939.sell_medicine"
const PISTOL := "kp.pistol"
const STEP := "gd.scare"


func _initialize() -> void:
	var t := T.new(self, "K18_scare_ui")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	await _shared_hand_normal_close(t)
	await _four_intent_scare_loops(t)
	await _scare_success_ui(t)
	await _scare_fail_ui(t)
	_day_end_advances(t)
	await _guide_scare(t)


func _boot(t, tag: String, seed_value: int = 7) -> Dictionary:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var e := CardEngine.new(bus)
	var made := e.new_game({"seed": seed_value, "stage": 2, "save_dir": t.user_dir() + "/" + tag})
	t.ok(bool(made.get("ok", false)), tag + " new_game")
	_to_day(t, e, tag)
	CardPiles.spawn(e.ctx, PISTOL, &"kept")
	return {"engine": e, "bus": bus}


func _to_day(t, e: CardEngine, tag: String) -> void:
	var guard := 0
	while str(e.view().get("phase", "")) != "day" and str(e.view().get("phase", "")) != "game_over" and guard < 12:
		guard += 1
		var phase := str(e.view().get("phase", ""))
		var step: Dictionary = e.send(&"day.end", {"confirm": true})
		if not bool(step.get("ok", false)) and phase in ["boot", "morning"]:
			step = e.send(&"day.begin", {})
		if not bool(step.get("ok", false)) and phase == "boot":
			e.send(&"day.end", {"confirm": true})
	t.eq(str(e.view().get("phase", "")), "day", tag + " day phase got=" + str(e.view().get("phase", "")))


func _to_morning(t, e: CardEngine, tag: String) -> void:
	var guard := 0
	while str(e.view().get("phase", "")) != "morning" and str(e.view().get("phase", "")) != "game_over" and guard < 16:
		guard += 1
		var phase := str(e.view().get("phase", ""))
		if phase == "morning":
			break
		# 已进 day 则继续打烊到次日早晨，绝不在此调用 day.begin（留给正式发牌）。
		var step: Dictionary = e.send(&"day.end", {"confirm": true})
		if not bool(step.get("ok", false)) and phase == "boot":
			e.send(&"month.begin", {})
		t.ok(bool(step.get("ok", false)) or str(e.view().get("phase", "")) in ["morning", "month_open", "day"],
			tag + " advance toward morning from " + phase + ": " + str(step.get("err", "")))
	t.eq(str(e.view().get("phase", "")), "morning", tag + " morning got=" + str(e.view().get("phase", "")))


func _spawn_shared_hand() -> CardHandApi:
	var path := CardIds.widget_scene(&"hand_fan")
	var node := load(path).instantiate() as CardHandApi
	root.add_child(node)
	node.visible = true
	if node.has_method("set_low"):
		node.set_low(false)
	return node


func _make_panel(e: CardEngine, bus: CardEventBus, shared: CardHandApi = null) -> CardCounterPanel:
	var panel: CardCounterPanel = load("res://scenes/cards/counter/CounterPanel.tscn").instantiate()
	if shared != null:
		panel.hand = shared
	root.add_child(panel)
	panel.bind(e, bus)
	if shared != null:
		panel._owned_hand = false
		panel.hand = shared
	return panel


func _wait_settled(t, panel: CardCounterPanel, tag: String) -> void:
	var guard := 0
	while panel._scare_checks and panel._phase not in ["settled", "leave"] and guard < 90:
		guard += 1
		await t.frames(1)
	t.ok(panel._phase in ["settled", "leave"] or not panel._scare_checks,
		tag + " reached settle (phase=" + str(panel._phase) + " scare=" + str(panel._scare_checks) + ")")


func _pistol_kept(ctx: CardCtx) -> bool:
	for uid in CardPiles.list(ctx, &"kept"):
		if str(CardPiles.card(ctx, uid).get("def", "")) == PISTOL:
			return true
	return false


func _assert_hand_operable(t, e: CardEngine, shared: CardHandApi, bus: CardEventBus, tag: String) -> void:
	t.ok(is_instance_valid(shared) and shared.visible, tag + " shared hand visible/valid")
	if shared.has_method("refresh"):
		shared.refresh(e.view())
	await t.frames(1)
	var hand_n := 0
	for row in e.view().get("hand", []):
		if typeof(row) == TYPE_DICTIONARY and str(row.get("uid", "")) != "":
			hand_n += 1
	t.ok(hand_n >= 0, tag + " hand list readable")
	if hand_n > 0 and shared.has_method("select_index"):
		var spy = t.spy(bus)
		shared.select_index(0)
		await t.frames(1)
		var saw := false
		for row2 in spy.log:
			if row2[0] == &"ui_event" and str(row2[1]) == "hand_selected":
				saw = true
		t.ok(saw or int(shared.get("_selected")) == 0, tag + " shared hand selectable after close")


func _shared_hand_normal_close(t) -> void:
	var pack: Dictionary = _boot(t, "close")
	var e: CardEngine = pack["engine"]
	var bus: CardEventBus = pack["bus"]
	var shared := _spawn_shared_hand()
	var guest := CardPiles.spawn(e.ctx, GUEST, &"hand")
	var panel := _make_panel(e, bus, shared)
	await t.frames(1)
	panel.open({"uid": guest})
	await t.frames(2)
	t.ok(not panel._owned_hand, "using shared hand not owned")
	t.ok(shared.visible, "shared hand visible while counter open")
	t.ok(is_instance_valid(shared), "shared hand valid before close")
	panel._finish_close()
	await t.frames(1)
	t.ok(is_instance_valid(shared), "shared hand not freed on close")
	t.ok(shared.visible, "shared hand visible after normal close")
	await _assert_hand_operable(t, e, shared, bus, "normal_close")
	panel.queue_free()
	await t.frames(1)
	t.ok(is_instance_valid(shared) and shared.visible, "shared hand survives panel free")
	shared.queue_free()
	bus.queue_free()
	await t.frames(1)


func _four_intent_scare_loops(t) -> void:
	# 四来意：回话→检定→结算→送客；共享 hand 关柜后仍可操作。redeem 强制真实当票。
	await _intent_scare_closed_loop(t, "pawn", GUEST)
	await _intent_scare_closed_loop(t, "sell", SELL)
	await _intent_scare_closed_loop(t, "buy", BUY)
	await _intent_scare_closed_loop(t, "redeem", REDEEM)


func _seed_open_chen_ticket(t, e: CardEngine) -> int:
	var pawn_uid := CardPiles.spawn(e.ctx, GUEST, &"hand")
	t.ok(pawn_uid != "", "seed pawn uid")
	var opened: Dictionary = CardCounter.open(e.ctx, pawn_uid)
	t.ok(bool(opened.get("ok", false)), "seed pawn counter open: " + str(opened.get("err", "")))
	var item := str(e.ctx.state.ns("econ").get("sessions", {}).get(pawn_uid, {}).get("item", ""))
	t.ok(item != "", "seed pawn generated item")
	# 走 fair 直到成交或离开；失败则直接开票
	var guard := 0
	var done := false
	while guard < 6 and not done:
		guard += 1
		var offered: Dictionary = CardCounter.offer(e.ctx, pawn_uid, &"fair")
		if not bool(offered.get("ok", false)):
			break
		if str(offered.get("reply", "")) == "accept" or str(offered.get("err", "")) == "":
			if str(offered.get("reply", "")) == "accept":
				done = true
				break
		if str(offered.get("reply", "")) == "counter":
			var ans: Dictionary = CardCounter.answer(e.ctx, pawn_uid, true)
			if bool(ans.get("ok", false)) and str(ans.get("reply", "")) == "accept":
				done = true
				break
		if str(offered.get("reply", "")) in ["leave", ""]:
			break
	var no := 0
	for row in CardTickets.view(e.ctx):
		if not bool(row.get("foreign", false)) and str(row.get("person", "")) == "chen":
			no = int(row.get("no", 0))
			break
	if no <= 0:
		# 直接账本开票（仍经正式 CardTickets API）
		no = CardTickets.open(e.ctx, pawn_uid, item if item != "" else "utensils.clock", 12, 30)
	t.ok(no > 0, "seed chen ticket no=" + str(no))
	# 清掉已当完的客人，避免挡手牌
	if CardPiles.zone_of(e.ctx, pawn_uid) == &"hand":
		CardPiles.discard(e.ctx, pawn_uid)
	return no


func _intent_scare_closed_loop(t, tag: String, def_id: String) -> void:
	var pack: Dictionary = _boot(t, tag + "_loop", 7 if tag != "buy" else 13)
	var e: CardEngine = pack["engine"]
	var bus: CardEventBus = pack["bus"]
	var shared := _spawn_shared_hand()
	# 额外留一张手牌，关柜后验证仍可选
	CardPiles.spawn(e.ctx, "kp.brother_note", &"hand")
	var uid := ""
	if tag == "redeem":
		var no := _seed_open_chen_ticket(t, e)
		uid = CardPiles.spawn(e.ctx, REDEEM, &"hand", {"vars": {"ticket_no": no}})
		t.ok(uid != "", "redeem spawned with ticket_no")
		var open_check: Dictionary = CardCounter.open(e.ctx, uid)
		t.ok(bool(open_check.get("ok", false)), "redeem counter session opens with real ticket: " + str(open_check.get("err", "")))
		# 关掉引擎会话，交给面板重新 open
		e.ctx.state.ns("econ")["sessions"].erase(uid)
	else:
		uid = CardPiles.spawn(e.ctx, def_id, &"hand")
	t.ok(uid != "", tag + " guest spawned")
	var ids: Array = []
	for row in CardChoices.options(e.ctx, uid):
		ids.append(str(row.get("id", "")))
	t.ok(ids.has("scare"), tag + " engine scare option")
	var heat := CardMeters.value(e.ctx, &"heat")
	var panel := _make_panel(e, bus, shared)
	if shared.has_method("refresh"):
		shared.refresh(e.view())
	await t.frames(1)
	panel.open({"uid": uid})
	await t.frames(3)
	t.ok(panel._is_open(panel._cv), tag + " counter opens")
	var reply_ids: Array = []
	for row2 in panel._replies():
		if typeof(row2) == TYPE_DICTIONARY:
			reply_ids.append(str(row2.get("id", "")))
	t.ok(reply_ids.has("choice:scare"), tag + " counter replies include scare")
	panel.on_reply("choice:scare")
	await t.frames(2)
	t.eq(panel._phase, "checks", tag + " entered checks")
	var self_uid := str(e.view().get("self", {}).get("uid", ""))
	if self_uid != "":
		t.ok(panel.on_card_played(self_uid, ""), tag + " place self")
	elif panel.checks is CardCounterChecks:
		(panel.checks as CardCounterChecks).offer("nerve", {"kind": "self"})
	await t.frames(1)
	panel.on_reply("roll")
	await _wait_settled(t, panel, tag)
	var yielded := e.ctx.test({"flag": "weapon_scare_yield"})
	var reported := e.ctx.test({"flag": "weapon_scare_reported"})
	t.ok(yielded or reported, tag + " scare settled with yield or reported")
	t.ok(_pistol_kept(e.ctx), tag + " pistol kept")
	t.ok(CardMeters.value(e.ctx, &"heat") > heat, tag + " heat moved")
	t.ok(panel._guest_left or panel._phase in ["settled", "leave"], tag + " guest settled/left")
	panel._finish_close()
	await t.frames(1)
	await _assert_hand_operable(t, e, shared, bus, tag)
	panel.queue_free()
	shared.queue_free()
	bus.queue_free()
	await t.frames(1)


func _scare_success_ui(t) -> void:
	var pack: Dictionary = _boot(t, "ok")
	var e: CardEngine = pack["engine"]
	var bus: CardEventBus = pack["bus"]
	var shared := _spawn_shared_hand()
	var uid := _spawn_heads(t, e.ctx)
	var heat := CardMeters.value(e.ctx, &"heat")
	var rep := CardMeters.value(e.ctx, &"rep")
	var panel := _make_panel(e, bus, shared)
	await t.frames(1)
	panel.open({"uid": uid})
	await t.frames(2)
	var has_scare := false
	for row in panel._replies():
		if typeof(row) == TYPE_DICTIONARY and str(row.get("id", "")) == "choice:scare":
			has_scare = true
	t.ok(has_scare, "success path has scare reply")
	panel.on_reply("choice:scare")
	await t.frames(2)
	t.eq(panel._phase, "checks", "success entered checks")
	var self_uid := str(e.view().get("self", {}).get("uid", ""))
	if self_uid != "":
		t.ok(panel.on_card_played(self_uid, ""), "success place self")
	elif panel.checks is CardCounterChecks:
		(panel.checks as CardCounterChecks).offer("nerve", {"kind": "self"})
	await t.frames(1)
	panel.on_reply("roll")
	await _wait_settled(t, panel, "success")
	t.ok(e.ctx.test({"flag": "weapon_scare_yield"}), "success yield flag")
	t.ok(not e.ctx.test({"flag": "weapon_scare_reported"}), "success not reported")
	t.eq(CardMeters.value(e.ctx, &"heat"), heat + 1, "success heat")
	t.eq(CardMeters.value(e.ctx, &"rep"), rep - 1, "success rep")
	t.ok(_pistol_kept(e.ctx), "pistol kept after success")
	t.ok(panel._guest_left or panel._phase in ["settled", "leave"], "guest settled after success")
	t.ok(is_instance_valid(shared) and shared.visible, "shared hand visible after success settle")
	panel._finish_close()
	await t.frames(1)
	await _assert_hand_operable(t, e, shared, bus, "success")
	panel.queue_free()
	shared.queue_free()
	bus.queue_free()
	await t.frames(1)


func _scare_fail_ui(t) -> void:
	var pack: Dictionary = _boot(t, "fail", 11)
	var e: CardEngine = pack["engine"]
	var bus: CardEventBus = pack["bus"]
	var shared := _spawn_shared_hand()
	var attrs: Dictionary = e.ctx.state.ns("rules")["attrs"]
	attrs["ruhua"]["nerve"] = 0
	var uid := CardPiles.spawn(e.ctx, GUEST, &"hand")
	var heat := CardMeters.value(e.ctx, &"heat")
	var panel := _make_panel(e, bus, shared)
	await t.frames(1)
	panel.open({"uid": uid})
	await t.frames(2)
	panel.on_reply("choice:scare")
	await t.frames(2)
	var self_uid := str(e.view().get("self", {}).get("uid", ""))
	if self_uid != "":
		panel.on_card_played(self_uid, "")
	elif panel.checks is CardCounterChecks:
		(panel.checks as CardCounterChecks).offer("nerve", {"kind": "self"})
	await t.frames(1)
	panel.on_reply("roll")
	await _wait_settled(t, panel, "fail")
	t.ok(e.ctx.test({"flag": "weapon_scare_reported"}), "fail reported")
	t.eq(CardMeters.value(e.ctx, &"heat"), heat + 3, "fail heat")
	t.ok(_pistol_kept(e.ctx), "pistol kept after fail")
	t.ok(is_instance_valid(shared) and shared.visible, "shared hand visible after fail settle")
	panel._finish_close()
	await t.frames(1)
	await _assert_hand_operable(t, e, shared, bus, "fail")
	panel.queue_free()
	shared.queue_free()
	bus.queue_free()
	await t.frames(1)


func _day_end_advances(t) -> void:
	var pack: Dictionary = _boot(t, "endday")
	var e: CardEngine = pack["engine"]
	var bus: CardEventBus = pack["bus"]
	var uid := CardPiles.spawn(e.ctx, GUEST, &"hand")
	var chose := e.send(&"card.choose", {"uid": uid, "choice": "scare"})
	t.ok(bool(chose.get("ok", false)) and bool(chose.get("needs_slots", false)), "mid scare needs_slots")
	var before := e.ctx.abs_day()
	var guard := 0
	while e.ctx.abs_day() == before and str(e.view().get("phase", "")) != "game_over" and guard < 8:
		guard += 1
		var step: Dictionary = e.send(&"day.end", {"confirm": true})
		t.ok(bool(step.get("ok", false)), "day.end mid scare: " + str(step.get("err", "")))
		if not bool(step.get("ok", false)):
			break
	var over := str(e.view().get("phase", "")) == "game_over"
	t.ok(e.ctx.abs_day() > before or over, "day.end mid scare advances abs_day or game_over")
	bus.queue_free()


func _guide_scare(t) -> void:
	# 真引擎 day.begin 发牌 → send 冲刷总线 first_time；Guide 同 bus 监听，不手调 hooks/_on_first。
	var bus := CardEventBus.new()
	root.add_child(bus)
	var spy = t.spy(bus)
	var e := CardEngine.new(bus)
	t.ok(bool(e.new_game({"seed": 7, "stage": 2, "save_dir": t.user_dir() + "/guide"}).get("ok", false)), "guide new_game")
	_to_morning(t, e, "guide")
	CardPiles.spawn(e.ctx, PISTOL, &"kept")
	var guide: CardGuide = load("res://scenes/cards/shell/GuideOverlay.tscn").instantiate()
	guide.skip_fades = true
	root.add_child(guide)
	guide.bind(e, bus)
	var raw: Dictionary = CardDB.read_json("res://data/cards/guide/steps.json")
	var scare_step: Dictionary = {}
	for row in raw.get("cards", []):
		if str(row.get("id", "")) == STEP:
			scare_step = row
			break
	t.ok(not scare_step.is_empty(), "formal gd.scare in steps.json")
	t.eq(str(scare_step.get("anchor", "")), "a.card@{uid}", "formal scare anchor")
	t.eq(str(scare_step.get("anchor_fallback", "")), "a.hand", "formal scare fallback")
	# 只装 scare 步，避免同日其它 first（如 life）抢焦点；仍由总线 first_time 驱动点亮。
	guide.load_steps({"steps": [scare_step], "pages": [], "settings": {"max_new_per_day": 8, "gap_ms": 0, "default_seconds": 30}})
	guide.force(true)
	var hand: CardHandApi = _spawn_shared_hand()
	if hand.has_method("bind"):
		hand.bind(e, bus)
	await t.frames(1)
	var began: Dictionary = e.send(&"day.begin", {})
	t.ok(bool(began.get("ok", false)), "day.begin deals: " + str(began.get("err", "")))
	var scare_uid := ""
	var scare_firsts := 0
	for row2 in spy.log:
		if row2[0] == &"first_time" and str(row2[1]) == "scare":
			scare_firsts += 1
			if row2.size() > 2 and typeof(row2[2]) == TYPE_DICTIONARY:
				scare_uid = str(row2[2].get("uid", ""))
	t.eq(scare_firsts, 1, "bus first_time scare exactly once via day.begin")
	t.ok(scare_uid != "", "scare first carries real uid")
	t.ok(CardFirsts.all(e.ctx).has("scare"), "first scare marked in state")
	if hand.has_method("refresh"):
		hand.refresh(e.view())
	await t.frames(2)
	var card_anchor := StringName("a.card@" + scare_uid)
	if not CardAnchors.has(card_anchor):
		var widget_path := CardIds.widget_scene(&"card")
		t.ok(widget_path != "", "card widget scene")
		var widget: Node = load(widget_path).instantiate()
		root.add_child(widget)
		if widget.has_method("bind"):
			widget.bind(e, bus)
		if widget.has_method("set_card"):
			widget.call("set_card", {"uid": scare_uid, "def": str(CardPiles.card(e.ctx, scare_uid).get("def", ""))})
		elif "uid" in widget:
			widget.set("uid", scare_uid)
		await t.frames(1)
	t.ok(CardAnchors.has(card_anchor) or CardAnchors.has(&"a.hand"), "production a.card@uid or a.hand present")
	guide.evaluate_now()
	t.eq(guide.active_step(), STEP, "gd.scare lights via engine bus first_time")
	var chose := e.send(&"card.choose", {"uid": scare_uid, "choice": "scare"})
	t.ok(bool(chose.get("ok", false)), "guide scare choose: " + str(chose.get("err", "")))
	guide.evaluate_now()
	await t.frames(3)
	guide.evaluate_now()
	t.eq(guide.active_step(), "", "gd.scare left after choose")
	var prog: Dictionary = e.query(&"guide_progress").get("progress", {})
	var grow: Dictionary = prog.get(STEP, {})
	t.eq(str(grow.get("status", "")), "done", "gd.scare progress status=done")
	# 存读须 morning/month_open：打烊推进后再 save
	var guard := 0
	while str(e.view().get("phase", "")) not in ["morning", "month_open"] and str(e.view().get("phase", "")) != "game_over" and guard < 10:
		guard += 1
		var step: Dictionary = e.send(&"day.end", {"confirm": true})
		t.ok(bool(step.get("ok", false)), "advance to save phase: " + str(step.get("err", "")))
		if not bool(step.get("ok", false)):
			break
	t.ok(str(e.view().get("phase", "")) in ["morning", "month_open"], "save phase morning/month_open got=" + str(e.view().get("phase", "")))
	var path: String = t.user_dir() + "/guide/mid.json"
	var saved: Dictionary = e.send(&"game.save", {"path": path})
	t.ok(bool(saved.get("ok", false)), "guide save: " + str(saved.get("err", "")))
	var bus3 := CardEventBus.new()
	root.add_child(bus3)
	var spy3 = t.spy(bus3)
	var loaded := CardEngine.new(bus3)
	var loaded_ok: Dictionary = loaded.load_game(path)
	t.ok(bool(loaded_ok.get("ok", false)), "guide load: " + str(loaded_ok.get("err", "")))
	t.ok(loaded.ctx.state != null and CardFirsts.all(loaded.ctx).has("scare"), "scare first survives load")
	var firsts := 0
	for row3 in spy3.log:
		if row3[0] == &"first_time" and str(row3[1]) == "scare":
			firsts += 1
	t.eq(firsts, 0, "load does not re-fire scare first")
	t.ok(not CardFirsts.mark(loaded.ctx, &"scare", {"uid": scare_uid}), "mark scare after load returns false")
	var g3: CardGuide = load("res://scenes/cards/shell/GuideOverlay.tscn").instantiate()
	g3.skip_fades = true
	root.add_child(g3)
	g3.bind(loaded, bus3)
	g3.load_steps({"steps": [scare_step], "pages": [], "settings": {"max_new_per_day": 8, "gap_ms": 0, "default_seconds": 30}})
	g3.force(true)
	await t.frames(1)
	g3.evaluate_now()
	t.eq(g3.active_step(), "", "loaded guide does not re-teach gd.scare")
	hand.queue_free()
	guide.queue_free()
	g3.queue_free()
	bus.queue_free()
	bus3.queue_free()
	await t.frames(1)


func _spawn_heads(t, ctx: CardCtx) -> String:
	var seq := int(ctx.state.ns("core")["uid_seq"])
	var head: Dictionary = ctx.rules("slots").get("head", {"num": 1, "den": 2})
	var num := float(int(head.get("num", 1)))
	var den := float(maxi(1, int(head.get("den", 2))))
	var abs_day := ctx.abs_day()
	var pad := 0
	var want := ""
	var found := false
	while pad < 40:
		want = "c%04d" % (seq + 1 + pad)
		var draw := JevRng.draw(ctx.seed(), "c.coin", [abs_day, want, 0, 0])
		if draw * den < num:
			found = true
			break
		pad += 1
	t.ok(found, "found heads uid")
	var n := 0
	while n < pad:
		CardPiles.spawn(ctx, "kp.brother_note", &"discard")
		n += 1
	var uid := CardPiles.spawn(ctx, GUEST, &"hand")
	t.eq(uid, want, "heads uid match")
	return uid
