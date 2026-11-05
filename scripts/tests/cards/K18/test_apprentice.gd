# K18: recruit, hidden loyalty, monthly growth, branches, shop-watching, day.end.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")


func _initialize() -> void:
	var t := T.new(self, "K18_apprentice")
	var db := CardDB.load_all("res://data/cards", {})
	t.ok(db.errors().is_empty(), "db loads: %s" % str(db.errors()))
	var e := _game(t)
	if e == null:
		t.finish()
		return
	_reach_ask(t, e)
	var ask := _uid(e, &"hand", "p.tudi.1939.ask")
	t.ok(ask != "", "ask card dealt on day 11")
	t.ok(CardFirsts.all(e.ctx).has("apprentice"), "first apprentice marked")
	t.ok(not CardFirsts.mark(e.ctx, &"apprentice", {}), "first does not fire twice")
	t.ok(bool(e.send(&"card.choose", {"uid": ask, "choice": "take"}).get("ok", false)), "choose take")
	t.eq(_counter(e, "apprentice_loyalty"), 40, "loyalty 40")
	t.ok(_uid(e, &"contacts", "ct.tudi") != "", "contact gained")
	var view := e.view()
	t.no_leaks(view)
	t.eq(bool(view.get("apprentice_desk", {}).get("has", false)), true, "desk has apprentice")
	t.ok(_contact_flag(view), "contact view marks apprentice")
	e.ctx.hooks.fire(e.ctx, &"month_close", {})
	t.eq(_counter(e, "apprentice_months"), 1, "one month")
	t.eq(_attr(e, "eye"), 2, "eye grew")
	t.ok(not _queued(e, "ev.any.apprentice_steal"), "honest month does not queue steal")
	e.ctx.hooks.fire(e.ctx, &"month_close", {})
	t.eq(_counter(e, "apprentice_months"), 1, "same stage does not grow twice")
	e.ctx.state.ns("loop")["stage"] = int(e.ctx.state.ns("loop").get("stage", 0)) + 1
	e.ctx.run([{"op": "counter", "key": "apprentice_loyalty", "delta": -30}], "t")
	e.ctx.hooks.fire(e.ctx, &"month_close", {})
	t.eq(_counter(e, "apprentice_months"), 2, "second month")
	t.ok(_queued(e, "ev.any.apprentice_steal"), "low loyalty queues steal")
	t.ok(_queued(e, "ev.any.apprentice_tip"), "lower loyalty queues tip")
	t.ok(not _queued(e, "ev.any.apprentice_succeed"), "loyalty 10 does not succeed")
	CardDayLoop.set_mode(e.ctx, &"street")
	e.ctx.hooks.fire(e.ctx, &"day_start", {})
	e.ctx.hooks.fire(e.ctx, &"settle", {})
	t.eq(bool(e.view().get("apprentice_desk", {}).get("watching", false)), true, "watching on the street")
	t.eq(_counter(e, "apprentice_watch_days"), 1, "one watch day")
	t.eq(_counter(e, "apprentice_skim_pending"), 6, "skim pending")
	var money_before := int(CardCurrency.money(e.ctx))
	t.no_leaks(e.view())
	CardDayLoop.set_mode(e.ctx, &"shop")
	e.ctx.hooks.fire(e.ctx, &"day_start", {})
	var audit := _uid(e, &"hand", "ev.any.apprentice_audit")
	t.ok(audit != "", "audit card on return")
	t.eq(bool(e.view().get("apprentice_desk", {}).get("watching", false)), false, "watching cleared")
	t.ok(bool(e.send(&"card.choose", {"uid": audit, "choice": "forgive"}).get("ok", false)), "forgive")
	t.eq(_counter(e, "apprentice_skim_pending"), 0, "books closed")
	t.eq(int(CardCurrency.money(e.ctx)), money_before - 6, "skim deducted once")
	t.eq(bool(e.ctx.state.ns("rules").get("flags", {}).get("apprentice_forgave", false)), true, "forgave")
	t.eq(bool(e.ctx.state.ns("rules").get("flags", {}).get("apprentice_skim", false)), true, "short books noted")
	t.no_leaks(e.view())
	var ended := e.send(&"day.end", {"confirm": true})
	t.ok(bool(ended.get("ok", false)), "day.end confirm: %s" % str(ended.get("err", "")))
	t.ok(str(e.ctx.state.ns("loop").get("phase", "")) != "day", "day.end left the day phase")
	e.ctx.state.ns("loop")["phase"] = "morning"
	var path := t.user_dir() + "/apprentice.sav"
	t.ok(bool(e.save_game(path).get("ok", false)), "save")
	var e2 := CardEngine.new()
	t.ok(bool(e2.load_game(path).get("ok", false)), "load")
	t.ok(CardFirsts.all(e2.ctx).has("apprentice"), "first survives load")
	t.ok(not CardFirsts.mark(e2.ctx, &"apprentice", {}), "load does not re-fire")
	_refuse(t)
	_succeed(t)
	_succeed_real_progression(t)
	_succeed_short(t)
	_ladder_prison_ending(t)
	t.finish()


func _game(t) -> CardEngine:
	var e := CardEngine.new()
	var res := e.new_game({"seed": 7, "stage": 1, "save_dir": t.user_dir()})
	t.ok(bool(res.get("ok", false)), "new game")
	if not bool(res.get("ok", false)):
		return null
	return e


func _reach_ask(t, e: CardEngine) -> void:
	var loop := e.ctx.state.ns("loop")
	loop["stage_day"] = 11
	loop["abs_day"] = 11
	loop["phase"] = "morning"
	var due := CardSchedule.due(e.ctx, 11)
	t.ok(due.has("p.tudi.1939.ask"), "schedule lists the ask")
	t.ok(bool(e.send(&"day.begin", {}).get("ok", false)), "begin day 11")


func _refuse(t) -> void:
	var e := _game(t)
	if e == null:
		return
	_reach_ask(t, e)
	var ask := _uid(e, &"hand", "p.tudi.1939.ask")
	t.ok(bool(e.send(&"card.choose", {"uid": ask, "choice": "refuse"}).get("ok", false)), "refuse")
	t.ok(_uid(e, &"contacts", "ct.tudi") == "", "refuse gains no contact")
	t.eq(bool(e.ctx.state.ns("rules").get("flags", {}).get("apprentice_refused", false)), true, "refused flag")
	t.ok(bool(e.send(&"day.end", {"confirm": true}).get("ok", false)), "day.end after refuse")


func _succeed(t) -> void:
	# 合同 succeed_months=2：非末关月底不发；末关 settle.next 真实进 month_close 后打开结局前受控窗口。
	# accept / later / ignore 各开一局，同一真实窗口：有界步数内 game_over(ending)，同日不重复结算。
	for path in ["accept", "later", "ignore"]:
		var e := _game(t)
		if e == null:
			return
		var snap := _open_final_window(t, e, path)
		if snap.is_empty():
			continue
		var succeed := _uid(e, &"hand", "ev.any.apprentice_succeed")
		if path != "ignore":
			var r := e.send(&"card.choose", {"uid": succeed, "choice": path})
			t.ok(bool(r.get("ok", false)), path + ": card.choose in window: " + str(r.get("err", "")))
			t.eq(str(e.ctx.state.ns("loop").get("phase", "")), "day", path + ": still in window after choose")
		_drain_to_ending(t, e, 3, path)
		_no_replay(t, e, snap, path)
		var flags: Dictionary = e.ctx.state.ns("rules").get("flags", {})
		if path == "accept":
			t.eq(bool(flags.get("apprentice_succeed", false)), true, "accept: succeed flag")
		else:
			t.eq(bool(flags.get("apprentice_succeed_later", false)), true, path + ": later flag (ignore = on_expire)")
			t.eq(bool(flags.get("apprentice_succeed", false)), false, path + ": not succeeded")
		t.ok(_uid(e, &"hand", "ev.any.apprentice_succeed") == "", path + ": succeed card left hand")
	# 非末关月底：不发、不开窗口
	var e4 := _game(t)
	if e4 == null:
		return
	_take_loyal(t, e4)
	var loop4 := e4.ctx.state.ns("loop")
	loop4["stage"] = 1
	loop4["stage_day"] = int(e4.ctx.db.stage(1).get("days", 30))
	CardDayLoop.set_phase(e4.ctx, CardIds.PH_SETTLE)
	t.ok(bool(e4.send(&"settle.next", {}).get("ok", false)), "non-final settle.next")
	t.eq(str(loop4.get("phase", "")), "month_close", "non-final stays month_close")
	t.eq(_counter(e4, "apprentice_months"), 1, "non-final one month")
	t.ok(_uid(e4, &"hand", "ev.any.apprentice_succeed") == "", "non-final month_close does not hand succeed")
	t.ok(not loop4.has("pre_ending_window"), "non-final opens no window")


func _take_loyal(t, e: CardEngine) -> void:
	_reach_ask(t, e)
	var ask := _uid(e, &"hand", "p.tudi.1939.ask")
	t.ok(bool(e.send(&"card.choose", {"uid": ask, "choice": "take"}).get("ok", false)), "take for succeed")
	e.ctx.run([{"op": "counter", "key": "apprentice_loyalty", "delta": 40}], "t")
	t.eq(_counter(e, "apprentice_loyalty"), 80, "loyalty 80 for succeed")


func _open_final_window(t, e: CardEngine, label: String) -> Dictionary:
	_take_loyal(t, e)
	var loop := e.ctx.state.ns("loop")
	# 1939 月底（还有下一关）：只长一个月
	loop["stage"] = 1
	loop["phase"] = "month_close"
	e.ctx.hooks.fire(e.ctx, &"month_close", {})
	t.eq(_counter(e, "apprentice_months"), 1, label + ": one month after 1939")
	# 1940 末关最后一天结算：公开 settle.next 真实进入 month_close
	loop["stage"] = 2
	t.ok(e.ctx.db.stage(3).is_empty(), label + ": 1940 is the final stage")
	loop["stage_day"] = int(e.ctx.db.stage(2).get("days", 30))
	if e.ctx.state.ns("meters").has("heat"):
		e.ctx.state.ns("meters")["heat"] = 0
	CardDayLoop.set_phase(e.ctx, CardIds.PH_SETTLE)
	var r := e.send(&"settle.next", {})
	t.ok(bool(r.get("ok", false)), label + ": final settle.next: " + str(r.get("err", "")))
	t.eq(_counter(e, "apprentice_months"), 2, label + ": two months reaches succeed_months")
	t.eq(str(loop.get("phase", "")), "day", label + ": pre-ending window is day phase")
	t.eq(str(loop.get("pre_ending_window", "")), "K18", label + ": window owned by K18")
	var succeed := _uid(e, &"hand", "ev.any.apprentice_succeed")
	t.ok(succeed != "", label + ": final month_close opens succeed in window")
	if succeed == "":
		return {}
	var ids: Array = []
	for ch in CardPiles.def_of(e.ctx, succeed).get("choices", []):
		ids.append(str(ch.get("id", "")))
	t.ok(ids.has("accept") and ids.has("later"), label + ": succeed choices accept/later")
	# 看铺中 + 在牢里：若窗口重跑 day_end/settle，会各多记一次
	e.ctx.run([{"op": "flag", "key": "apprentice_watching", "value": true}], "t")
	CardPrison.arrest(e.ctx, "t")
	return _snap(e)


func _snap(e: CardEngine) -> Dictionary:
	var loop := e.ctx.state.ns("loop")
	var attrs: Array = []
	for a in ["eye", "tongue", "pull", "nerve"]:
		attrs.append(_attr(e, a))
	return {
		"watch": _counter(e, "apprentice_watch_days"),
		"skim": _counter(e, "apprentice_skim_pending"),
		"months": _counter(e, "apprentice_months"),
		"nights": int(e.ctx.state.ns("ladder").get("prison", {}).get("nights", 0)),
		"money": int(CardCurrency.money(e.ctx)),
		"attrs": attrs,
		"abs_day": int(loop.get("abs_day", 0)),
		"stage_day": int(loop.get("stage_day", 0)),
		"stage": int(loop.get("stage", 0)),
	}


func _no_replay(t, e: CardEngine, before: Dictionary, label: String) -> void:
	var after := _snap(e)
	for k in before:
		t.eq(after[k], before[k], label + ": no same-day replay of " + str(k))
	t.ok(not e.ctx.state.ns("loop").has("pre_ending_window"), label + ": window closed")


func _succeed_real_progression(t) -> void:
	# 公开指令：1939 收徒→打烊到月底；跳年 1940 后快进到关底几天再公开打烊，避开忽略牌入狱。
	var e := _game(t)
	if e == null:
		return
	_reach_ask(t, e)
	var ask := _uid(e, &"hand", "p.tudi.1939.ask")
	t.ok(bool(e.send(&"card.choose", {"uid": ask, "choice": "take"}).get("ok", false)), "real take")
	e.ctx.run([{"op": "counter", "key": "apprentice_loyalty", "delta": 40}], "t")
	t.eq(_counter(e, "apprentice_loyalty"), 80, "real loyalty 80")
	_advance_to_month_close(t, e, 120)
	t.eq(str(e.view().get("phase", "")), "month_close", "1939 reached month_close")
	t.eq(_counter(e, "apprentice_months"), 1, "one month after 1939")
	t.ok(_uid(e, &"hand", "ev.any.apprentice_succeed") == "", "1939 close: below threshold no succeed")
	t.ok(bool(e.send(&"month.next", {}).get("ok", false)), "1939 month.next")
	t.eq(str(e.view().get("phase", "")), "year_jump", "year jump after 1939")
	t.ok(bool(e.send(&"year.next", {}).get("ok", false)), "enter 1940")
	t.eq(int(e.ctx.state.ns("loop").get("stage", 0)), 2, "stage 1940")
	# 开月
	if str(e.view().get("phase", "")) == "month_open":
		e.send(&"wheel.spin", {"wheel": "wh.month", "uid": ""})
		t.ok(bool(e.send(&"month.begin", {}).get("ok", false)), "1940 month.begin")
	# 快进到关底前一天（公开链仍走 day.begin/end/night/settle）；清风声避免忽略入狱
	# 清风声，避免忽略牌入狱；快进到关底前一天再公开打烊
	if e.ctx.state.ns("meters").has("heat"):
		e.ctx.state.ns("meters")["heat"] = 0
	var loop: Dictionary = e.ctx.state.ns("loop")
	var days := int(e.ctx.db.stage(2).get("days", 30))
	loop["stage_day"] = days - 1
	loop["abs_day"] = int(loop.get("abs_day", 40)) + 1
	CardDayLoop.set_phase(e.ctx, CardIds.PH_MORNING)
	t.ok(_uid(e, &"hand", "ev.any.apprentice_succeed") == "", "before final close: no succeed yet months=" + str(_counter(e, "apprentice_months")))
	_advance_to_month_close(t, e, 40)
	var ph := str(e.view().get("phase", ""))
	if ph == "month_close" and _counter(e, "apprentice_months") >= 2:
		# 若钩子已切 day，phase 不会停在 month_close；此处兼容
		pass
	t.eq(_counter(e, "apprentice_months"), 2, "two months via real progression")
	var succeed := _uid(e, &"hand", "ev.any.apprentice_succeed")
	t.ok(succeed != "", "pre-ending window handed succeed phase=" + str(e.ctx.state.ns("loop").get("phase", "")))
	t.eq(str(e.ctx.state.ns("loop").get("phase", "")), "day", "pre-ending phase is day")
	if succeed == "":
		return
	t.ok(bool(e.send(&"card.choose", {"uid": succeed, "choice": "accept"}).get("ok", false)), "accept on day after real months")
	var snap := _snap(e)
	_drain_to_ending(t, e, 3, "real")
	_no_replay(t, e, snap, "real")


func _succeed_short(t) -> void:
	# 末关最后一天：两笔抵押（含铺面）且现金为 0。短款未处理前不能进结局。
	# day_end 与主动认了的 accept / later / ignore 都必须进可操作接班窗口，并核对利息、铺面、月账。
	# 阶梯终局不在这里放行，见 _ladder_prison_ending。
	for how in ["resolve", "day_end"]:
		for path in ["accept", "later", "ignore"]:
			_short_case(t, how, path)


func _short_case(t, how: String, path: String) -> void:
	var e := _game(t)
	if e == null:
		return
	var label := how + "/" + path
	if not _arm_final_short(t, e, label):
		return
	var grown := _snap(e)
	var loop := e.ctx.state.ns("loop")
	t.eq(_counter(e, "apprentice_months"), 2, label + ": grown once before shorts")
	t.eq(str(loop.get("phase", "")), "month_close", label + ": short keeps month_close")
	t.eq(str(loop.get("open_panel", {}).get("kind", "")), "short", label + ": short panel")
	t.ok(_uid(e, &"hand", "ev.any.apprentice_succeed") == "", label + ": no succeed card yet")
	var blocked := e.send(&"day.end", {"confirm": false})
	t.eq(str(blocked.get("err", "")), "must_resolve_pending", label + ": day.end before short")
	t.eq(str(loop.get("phase", "")), "month_close", label + ": day.end did not leave month_close")
	t.ok(str(loop.get("reason", "")) != "ending", label + ": not an ending yet")
	if how == "day_end":
		var advanced := e.send(&"day.end", {"confirm": true})
		t.ok(bool(advanced.get("ok", false)), label + ": day.end default " + str(advanced.get("err", "")))
		# 三分支夹具必须保证非终局：day.end 默认认短款后若仍停在 month_close，继续公开推进到窗口。
		t.ok(str(loop.get("phase", "")) != "game_over", label + ": day_end must not ladder-end (reason=" + str(loop.get("reason", "")) + ")")
		if str(loop.get("phase", "")) == "month_close":
			if not _resolve_shorts(t, e, label):
				return
	elif not _resolve_shorts(t, e, label):
		return
	_assert_window_after_accounts(t, e, label, grown)
	var succeed := _uid(e, &"hand", "ev.any.apprentice_succeed")
	var in_window := succeed != "" and str(loop.get("phase", "")) == "day"
	t.ok(in_window, label + ": operable succeed window required")
	if not in_window:
		return
	if path != "ignore":
		var chosen := e.send(&"card.choose", {"uid": succeed, "choice": path})
		t.ok(bool(chosen.get("ok", false)), label + ": choose " + str(chosen.get("err", "")))
		t.eq(str(loop.get("phase", "")), "day", label + ": still in window")
	e.ctx.run([{"op": "flag", "key": "apprentice_watching", "value": true}], "t")
	CardPrison.arrest(e.ctx, "t")
	var snap := _snap(e)
	_drain_to_ending(t, e, 4, label)
	_no_replay(t, e, snap, label)
	t.eq(_counter(e, "apprentice_months"), int(grown["months"]), label + ": months still once")
	var flags: Dictionary = e.ctx.state.ns("rules").get("flags", {})
	if path == "accept":
		t.eq(bool(flags.get("apprentice_succeed", false)), true, label + ": accept flag")
	else:
		t.eq(bool(flags.get("apprentice_succeed_later", false)), true, label + ": later flag")
		t.eq(bool(flags.get("apprentice_succeed", false)), false, label + ": not succeeded")


func _arm_final_short(t, e: CardEngine, label: String) -> bool:
	_take_loyal(t, e)
	var loop := e.ctx.state.ns("loop")
	loop["stage"] = 1
	loop["phase"] = "month_close"
	e.ctx.hooks.fire(e.ctx, &"month_close", {})
	t.eq(_counter(e, "apprentice_months"), 1, label + ": first month without short")
	CardDayLoop.set_phase(e.ctx, CardIds.PH_DAY)
	for id in ["es.jewel_cabinet", "es.shopfront"]:
		var mortgaged := e.send(&"estate.mortgage", {"estate": id})
		t.ok(bool(mortgaged.get("ok", false)), label + ": mortgage " + id + " " + str(mortgaged.get("err", "")))
		if not bool(mortgaged.get("ok", false)):
			return false
	var cash := int(CardCurrency.money(e.ctx))
	if cash > 0:
		e.ctx.run([{"op": "money", "delta": -cash, "reason": "k18.test"}], "t")
	t.eq(int(CardCurrency.money(e.ctx)), 0, label + ": cash cleared")
	loop["stage"] = 2
	t.ok(e.ctx.db.stage(3).is_empty(), label + ": 1940 is final")
	loop["stage_day"] = int(e.ctx.db.stage(2).get("days", 30))
	if e.ctx.state.ns("meters").has("heat"):
		e.ctx.state.ns("meters")["heat"] = 0
	CardDayLoop.set_phase(e.ctx, CardIds.PH_SETTLE)
	var settled := e.send(&"settle.next", {})
	t.ok(bool(settled.get("ok", false)), label + ": final settle " + str(settled.get("err", "")))
	return bool(settled.get("ok", false))


func _resolve_shorts(t, e: CardEngine, label: String) -> bool:
	var guard := 0
	while guard < 8:
		guard += 1
		if str(e.ctx.state.ns("loop").get("phase", "")) == "game_over":
			t.ok(false, label + ": ended while short still open")
			return false
		var panel: Dictionary = CardShortLadder.view(e.ctx)
		if panel.is_empty():
			break
		var resolved := e.send(&"short.resolve", {"source": str(panel.get("source", "")), "by": "default"})
		t.ok(bool(resolved.get("ok", false)), label + ": short.resolve " + str(resolved.get("err", "")))
		if not bool(resolved.get("ok", false)):
			return false
		if str(e.ctx.state.ns("loop").get("phase", "")) == "day":
			break
		var nxt := e.send(&"month.next", {})
		t.ok(bool(nxt.get("ok", false)), label + ": month.next " + str(nxt.get("err", "")))
		if not bool(nxt.get("ok", false)):
			return false
	return str(e.ctx.state.ns("loop").get("phase", "")) != "game_over"


func _assert_window_after_accounts(t, e: CardEngine, label: String, grown: Dictionary) -> void:
	# P2：禁止把任意非 ending 的 game_over 当接班窗口验收通过；必须非终局且可操作接班。
	var loop := e.ctx.state.ns("loop")
	var phase := str(loop.get("phase", ""))
	t.eq(phase, "day", label + ": operable window, not " + phase + "/" + str(loop.get("reason", "")))
	t.ok(_uid(e, &"hand", "ev.any.apprentice_succeed") != "", label + ": succeed card in window")
	t.eq(str(loop.get("pre_ending_window", "")), "K18", label + ": window owner")
	t.eq(str(CardMortgage._entry(e.ctx, "es.shopfront").get("status", "")), "lost", label + ": shop lost first")
	t.eq(str(loop.get("mode", "")), "street", label + ": on the street")
	t.eq(int(e.ctx.state.ns("ladder").get("month_closed_stage", -1)), 2, label + ": ladder month finished")
	t.eq(int(CardMortgage._entry(e.ctx, "es.jewel_cabinet").get("interest_paid_stage", -1)), 2, label + ": jewel interest")
	t.eq(int(CardMortgage._entry(e.ctx, "es.shopfront").get("interest_paid_stage", -1)), 2, label + ": shop interest")
	t.eq(CardShortLadder.view(e.ctx).is_empty(), true, label + ": short gone")
	t.eq(bool(loop.get("month_pending", false)), false, label + ": pending clear")
	t.eq(str(loop.get("open_panel", {}).get("kind", "")), "", label + ": panel clear")
	t.eq(_counter(e, "apprentice_months"), int(grown["months"]), label + ": no second growth")
	t.eq(_snap(e)["attrs"], grown["attrs"], label + ": attrs once")


## 真阶梯终局：牢房打满。原因必须是 prison，不能用「不是 ending」蒙混，也不打开接班窗口。
func _ladder_prison_ending(t) -> void:
	var e := _game(t)
	if e == null:
		return
	_take_loyal(t, e)
	e.ctx.run([{"op": "counter", "key": "apprentice_months", "delta": 2}], "t")
	t.eq(_counter(e, "apprentice_months"), 2, "prison: months at succeed threshold")
	t.eq(_counter(e, "apprentice_loyalty"), 80, "prison: loyalty at succeed threshold")
	t.eq(str(e.ctx.state.ns("loop").get("phase", "")), "day", "prison: normal day, not a succeed window")
	t.ok(not e.ctx.state.ns("loop").has("pre_ending_window"), "prison: window not open")
	CardPrison.arrest(e.ctx, "t")
	var limit := int(e.ctx.rules("ladder").get("prison", {}).get("max_days", 3))
	e.ctx.state.ns("ladder")["prison"]["nights"] = limit - 1
	var blocked := e.send(&"day.end", {"confirm": false})
	t.eq(str(blocked.get("err", "")), "must_resolve_pending", "prison: unconfirmed day.end does not end")
	t.eq(str(e.ctx.state.ns("loop").get("phase", "")), "day", "prison: still day")
	var ended := e.send(&"day.end", {"confirm": true})
	t.ok(bool(ended.get("ok", false)), "prison: confirmed day.end " + str(ended.get("err", "")))
	t.eq(str(e.ctx.state.ns("loop").get("phase", "")), "game_over", "prison: game over")
	t.eq(str(e.ctx.state.ns("loop").get("reason", "")), "prison", "prison: reason")
	t.eq(int(e.ctx.state.ns("ladder").get("prison", {}).get("nights", 0)), limit, "prison: nights at limit")
	t.ok(int(e.ctx.state.ns("econ").get("shop_closed_until", -1)) >= e.ctx.abs_day(), "prison: shop closed for the failed night")
	t.ok(not e.ctx.state.ns("loop").has("pre_ending_window"), "prison: no succeed window")
	t.ok(_uid(e, &"hand", "ev.any.apprentice_succeed") == "", "prison: succeed card not dealt")


func _advance_to_month_close(t, e: CardEngine, guard_max: int) -> void:
	var guard := 0
	# Stop when month_close OR pre-ending day window (succeed already in hand after final close).
	while guard < guard_max:
		guard += 1
		var ph := str(e.view().get("phase", ""))
		if ph == "month_close":
			break
		if ph == "day" and _uid(e, &"hand", "ev.any.apprentice_succeed") != "":
			break
		if ph == "game_over":
			break
		match ph:
			"month_open":
				e.send(&"wheel.spin", {"wheel": "wh.month", "uid": ""})
				e.send(&"month.begin", {})
			"morning":
				e.send(&"day.begin", {})
			"day":
				e.send(&"day.end", {"confirm": true})
			"night":
				# Skip night with empty def (always legal); avoids no_such_choice on choice cards.
				e.send(&"night.choose", {"def": ""})
			"settle":
				e.send(&"settle.next", {})
			"year_jump":
				e.send(&"year.next", {})
			_:
				e.send(&"day.end", {"confirm": true})
	var end_ph := str(e.view().get("phase", ""))
	t.ok(end_ph == "month_close" or _uid(e, &"hand", "ev.any.apprentice_succeed") != "", "advance reached month_close or succeed window phase=" + end_ph + " months=" + str(_counter(e, "apprentice_months")) + " guard=" + str(guard))


func _drain_to_ending(t, e: CardEngine, guard_max: int, label: String) -> void:
	# 每条命令必须成功；有界步数内必须 game_over 且原因是 ending，停在 day 不算过。
	var guard := 0
	while str(e.view().get("phase", "")) != "game_over" and guard < guard_max:
		guard += 1
		var ph := str(e.view().get("phase", ""))
		var r: Dictionary = {}
		if ph == "day":
			r = e.send(&"day.end", {"confirm": true})
		elif ph == "month_close":
			r = e.send(&"month.next", {})
		else:
			t.ok(false, label + ": unexpected phase before ending: " + ph)
			break
		t.ok(bool(r.get("ok", false)), label + ": " + ph + " command ok: " + str(r.get("err", "")))
		if not bool(r.get("ok", false)):
			break
	t.eq(str(e.view().get("phase", "")), "game_over", label + ": game_over within " + str(guard_max) + " steps (took " + str(guard) + ")")
	t.eq(str(e.ctx.state.ns("loop").get("reason", "")), "ending", label + ": ending reason")


func _uid(e: CardEngine, zone: StringName, def_id: String) -> String:
	for uid in CardPiles.list(e.ctx, zone):
		if str(CardPiles.card(e.ctx, uid).get("def", "")) == def_id:
			return str(uid)
	return ""


func _counter(e: CardEngine, key: String) -> int:
	return int(e.ctx.state.ns("rules").get("counters", {}).get(key, 0))


func _attr(e: CardEngine, attr: String) -> int:
	return int(CardMeters.attr(e.ctx, "tudi", StringName(attr)))


func _queued(e: CardEngine, def_id: String) -> bool:
	for row in e.ctx.state.ns("core").get("queue", []):
		if str(row.get("def", "")) == def_id:
			return true
	return false


func _contact_flag(view: Dictionary) -> bool:
	for row in view.get("contacts", []):
		if typeof(row) == TYPE_DICTIONARY and str(row.get("person", "")) == "tudi":
			return bool(row.get("apprentice", false))
	return false
