# 日循环与关卡节奏；早上先触发钩子再发牌，所有阶段变化都经 set_phase。
# G02：合同 1.2 的打烊指令在每个局内阶段推进一步，后果由数据与各模块钩子决定。
class_name CardDayLoop
extends RefCounted

const Reports = preload("res://scripts/cards/loop/loop_reports.gd")
const EndRules = preload("res://scripts/cards/loop/end_day_rules.gd")

static func begin_stage(ctx: CardCtx, stage: int) -> void:
	var loop := ctx.state.ns("loop")
	var prev_abs := int(loop.get("abs_day", 0))
	var year: Dictionary = loop.get("reports", {}).get("year", {"lines": []})
	loop.merge({"_v": 1, "mode": str(CardIds.MODE_SHOP), "stage": stage, "stage_day": 0,
		"abs_day": prev_abs, "minute": int(ctx.rules("loop").get("open_minute", 480)), "goals": [],
		"night": {"offers": [], "chosen": "", "choice": ""}, "gold_left": [], "end_lines": [], "notices": [], "sched_done": {},
		"reports": {"settle": {"lines": []}, "month": {"lines": []}, "year": year},
		"open_panel": {"kind": "", "args": {}}, "reason": "", "month_pending": false}, true)
	set_phase(ctx, CardIds.PH_BOOT)
	ctx.hooks.fire(ctx, CardIds.HOOK_STAGE_START, {"stage": stage})

static func open_month(ctx: CardCtx) -> Dictionary:
	set_phase(ctx, CardIds.PH_MONTH_OPEN)
	CardFirsts.mark(ctx, &"month_open", {})
	ctx.hooks.fire(ctx, CardIds.HOOK_MONTH_OPEN, {})
	return {"ok": true, "err": ""}

static func enter_morning(ctx: CardCtx) -> void:
	var loop := ctx.state.ns("loop")
	loop["stage_day"] = int(loop.get("stage_day", 0)) + 1
	loop["abs_day"] = ctx.abs_day() + 1
	loop["minute"] = int(ctx.rules("loop").get("open_minute", 480))
	loop["notices"] = []
	loop["gold_left"] = []
	loop["end_lines"] = []
	loop["night"] = {"offers": [], "chosen": "", "choice": ""}
	loop["reports"]["settle"] = {"lines": []}
	request_panel(ctx, &"", {})
	set_phase(ctx, CardIds.PH_MORNING)
	ctx.hooks.fire(ctx, CardIds.HOOK_DAY_START, {"abs_day": ctx.abs_day()})
	ctx.emit(&"notice", ["g02.notice." + str(ctx.state.ns("fate").get("weather", "clear")), {}])
	if CardCalendar.is_market_day(ctx, int(loop["stage_day"])):
		ctx.emit(&"notice", ["g02.notice.market_day", {}])
	CardFirsts.mark(ctx, &"notice", {})
	loop["morning_snapshot"] = Reports.snapshot(ctx)

static func begin_day(ctx: CardCtx) -> Dictionary:
	if str(ctx.state.ns("loop").get("phase", "")) != "morning":
		return {"ok": false, "err": CardIds.ERR_BAD_PHASE}
	var due := CardSchedule.due(ctx, ctx.abs_day())
	var dealt := CardComposer.compose(ctx)
	if str(ctx.state.ns("loop").get("phase", "")) != "game_over":
		set_phase(ctx, CardIds.PH_DAY)
	var done: Dictionary = ctx.state.ns("loop").get("sched_done", {})
	for uid in dealt:
		var id := str(CardPiles.card(ctx, uid).get("def", ""))
		if due.has(id):
			done[id] = ctx.abs_day()
	ctx.state.ns("loop")["sched_done"] = done
	for uid in CardGoldRule.pending(ctx):
		CardFirsts.mark(ctx, &"gold", {"uid": uid, "def": str(CardPiles.card(ctx, uid)["def"]),
			"person": str(CardPiles.def_of(ctx, uid).get("person", ""))})
	return {"ok": true, "err": "", "dealt": dealt}

static func end_day(ctx: CardCtx, confirm: bool) -> Dictionary:
	var preview := EndRules.preview(ctx)
	if str(preview["step"]) == "":
		return {"ok": false, "err": CardIds.ERR_BAD_PHASE}
	for row in preview["items"]:
		if CardIds.END_MUST_KINDS.has(StringName(str(row["kind"]))):
			CardFirsts.mark(ctx, &"must_resolve", {"uid": str(row["uid"])})
			break
	for row in preview["items"]:
		if str(row["kind"]) == "gold_leave":
			CardFirsts.mark(ctx, &"gold_leave", {"uid": str(row["uid"])})
			break
	if not confirm and bool(preview["needs_confirm"]):
		preview.merge({"ok": false, "err": "must_resolve_pending"})
		return preview
	var result := _advance_end(ctx, str(preview["step"]), preview["items"])
	result.merge(preview, true)
	return result

static func _advance_end(ctx: CardCtx, step: String, items: Array) -> Dictionary:
	if step not in ["end_day", "month_next"] and CardShortLadder.view(ctx).has("options"):
		var short := CardShortLadder.view(ctx)
		var accepted := CardShortLadder.resolve(ctx, {"source": str(short.get("source", "")), "by": "default"})
		if not bool(accepted.get("ok", false)): return accepted
		var lines: Array = ctx.state.ns("loop").get("end_lines", [])
		lines.append_array(EndRules.report_lines(items))
		ctx.state.ns("loop")["end_lines"] = lines
		if str(ctx.state.ns("loop").get("phase", "")) == "game_over":
			Reports.finish_settle(ctx, 0)
			return {"ok": true, "err": ""}
	match step:
		"end_day": return _close_day(ctx, items)
		"skip_night": return choose_night_choice(ctx, "", "")
		"next_day": return settle(ctx)
		"open_day": return begin_day(ctx)
		"begin_month":
			if EndRules.month_unspun(ctx):
				var spun := CardWheel.spin(ctx, "wh.month", "")
				if not bool(spun.get("ok", false)): return spun
				if str(ctx.state.ns("loop").get("phase", "")) == "game_over": return {"ok": true, "err": ""}
			enter_morning(ctx)
			return {"ok": true, "err": ""}
		"month_next": return _advance_month(ctx)
		"year_next": return jump_year(ctx)
	return {"ok": false, "err": CardIds.ERR_BAD_PHASE}

static func _close_day(ctx: CardCtx, items: Array) -> Dictionary:
	var loop := ctx.state.ns("loop")
	if str(loop.get("pre_ending_window", "")) != "":
		return _close_pre_ending_window(ctx, items)
	loop["minute"] = maxi(int(loop.get("minute", 480)), int(ctx.rules("loop").get("close_minute", 1080)))
	loop["end_lines"] = EndRules.report_lines(items)
	ctx.hooks.fire(ctx, CardIds.HOOK_DAY_END, {})
	request_panel(ctx, &"", {})
	if str(loop.get("phase", "")) == "game_over":
		Reports.finish_settle(ctx, ctx.out.size())
		return {"ok": true, "err": ""}
	loop["night"] = {"offers": Array(CardComposer.night_offers(ctx)), "chosen": "", "choice": ""}
	set_phase(ctx, CardIds.PH_NIGHT)
	CardFirsts.mark(ctx, &"night", {})
	return {"ok": true, "err": ""}

## 结局前受控窗口（共享归属 G02×K18，合同 1.4 / #187）：只在末关、月账已经没有短款时
## 临时回到 day，让窗口牌走合法 card.choose。month_pending 或 short 面板时返回 false，并记下
## pre_ending_due；等 close_month 在钩子之后确认账务完成再开，避免用钩子里过期的 pending 误判。
static func open_pre_ending_window(ctx: CardCtx, owner: String) -> bool:
	var loop := ctx.state.ns("loop")
	if str(loop.get("phase", "")) != str(CardIds.PH_MONTH_CLOSE) or owner == "":
		return false
	if not ctx.db.stage(int(loop.get("stage", 0)) + 1).is_empty():
		loop.erase("pre_ending_due")
		return false
	if bool(loop.get("month_pending", false)) or str(loop.get("open_panel", {}).get("kind", "")) == "short":
		loop["pre_ending_due"] = owner
		return false
	loop.erase("pre_ending_due")
	loop["pre_ending_window"] = owner
	set_phase(ctx, CardIds.PH_DAY)
	return true


## 窗口打烊：只让 G02 自有的牌离场（未理的窗口牌按 on_expire 落地），然后恢复 month_close，
## 走正常 close_month。不请空面板、不硬写 month_pending（短款和未完成的月账留在原流程里）。
## 不 fire HOOK_DAY_END、不发夜牌、不 fire HOOK_SETTLE，不推进 abs_day。
static func _close_pre_ending_window(ctx: CardCtx, items: Array) -> Dictionary:
	var loop := ctx.state.ns("loop")
	loop["end_lines"] = EndRules.report_lines(items)
	EndRules.execute_owned(ctx)
	loop.erase("pre_ending_window")
	if str(loop.get("phase", "")) == "game_over":
		return {"ok": true, "err": ""}
	set_phase(ctx, CardIds.PH_MONTH_CLOSE)
	return close_month(ctx)

static func _advance_month(ctx: CardCtx) -> Dictionary:
	# Monthly shortages may arrive successively; each default acceptance allows the idempotent hooks to resume.
	while str(ctx.state.ns("loop").get("phase", "")) == "month_close":
		if CardShortLadder.view(ctx).has("options"):
			var lines: Array = ctx.state.ns("loop")["reports"]["month"]["lines"]
			lines.append_array(EndRules.report_lines(EndRules.preview(ctx)["items"]))
			var short := CardShortLadder.view(ctx)
			var accepted := CardShortLadder.resolve(ctx, {"source": str(short.get("source", "")), "by": "default"})
			if not bool(accepted.get("ok", false)): return accepted
		var result := close_month(ctx)
		if not bool(result.get("ok", false)): return result
	return {"ok": true, "err": ""}

static func choose_night(ctx: CardCtx, def_id: String) -> Dictionary:
	return choose_night_choice(ctx, def_id, "")

static func choose_night_choice(ctx: CardCtx, def_id: String, choice: String) -> Dictionary:
	var loop := ctx.state.ns("loop")
	if str(loop.get("phase", "")) != "night":
		return {"ok": false, "err": CardIds.ERR_BAD_PHASE}
	var offers: Array = loop.get("night", {}).get("offers", [])
	# An empty definition skips tonight even when eligible offers exist.
	if not offers.has(def_id) and def_id != "":
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	var d := ctx.db.def(def_id)
	var choices: Array = d.get("choices", [])
	var selected: Dictionary = {}
	for row in choices:
		if str(row.get("id", "")) == choice:
			selected = row
	if (not choices.is_empty() and selected.is_empty()) or (choices.is_empty() and choice != ""):
		return {"ok": false, "err": "no_such_choice"}
	loop["night"]["chosen"] = def_id
	loop["night"]["choice"] = choice
	ctx.run(selected.get("effects", []), def_id + "/choice/" + choice)
	ctx.run(d.get("effects", {}).get("on_choose", []), def_id + "/on_choose")
	ctx.hooks.fire(ctx, CardIds.HOOK_NIGHT_CHOSEN, {"def": def_id})
	if str(loop.get("phase", "")) != "game_over":
		set_phase(ctx, CardIds.PH_SETTLE)
		var start := ctx.out.size()
		ctx.hooks.fire(ctx, CardIds.HOOK_SETTLE, {})
		Reports.finish_settle(ctx, start)
		CardFirsts.mark(ctx, &"settle", {})
	return {"ok": true, "err": ""}

static func settle(ctx: CardCtx) -> Dictionary:
	var loop := ctx.state.ns("loop")
	if str(loop.get("phase", "")) != "settle":
		return {"ok": false, "err": CardIds.ERR_BAD_PHASE}
	if int(loop.get("stage_day", 0)) >= int(ctx.db.stage(int(loop.get("stage", 0))).get("days", 30)):
		set_phase(ctx, CardIds.PH_MONTH_CLOSE)
		var start := ctx.out.size()
		ctx.hooks.fire(ctx, CardIds.HOOK_MONTH_CLOSE, {})
		Reports.finish_month(ctx, start)
		loop["month_pending"] = str(loop.get("open_panel", {}).get("kind", "")) == "short"
		CardFirsts.mark(ctx, &"month_close", {})
	else:
		enter_morning(ctx)
	return {"ok": true, "err": "", "next_phase": str(loop["phase"])}

static func close_month(ctx: CardCtx) -> Dictionary:
	var loop := ctx.state.ns("loop")
	if str(loop.get("phase", "")) != "month_close":
		return {"ok": false, "err": CardIds.ERR_BAD_PHASE}
	if bool(loop.get("month_pending", false)):
		if str(loop.get("open_panel", {}).get("kind", "")) == "short":
			return {"ok": false, "err": "short_pending"}
		var start := ctx.out.size()
		ctx.hooks.fire(ctx, CardIds.HOOK_MONTH_CLOSE, {})
		Reports.extend_month(ctx, start)
		loop["month_pending"] = str(loop.get("open_panel", {}).get("kind", "")) == "short"
		if bool(loop["month_pending"]):
			return {"ok": true, "err": "", "next_phase": str(loop["phase"])}
		if str(loop.get("phase", "")) == "game_over":
			return {"ok": true, "err": ""}
		# 钩子里若已经离开 month_close（受控窗口或阶梯局终），不要接着 finish_game 盖掉。
		if str(loop.get("phase", "")) != "month_close":
			return {"ok": true, "err": "", "next_phase": str(loop["phase"])}
		# pending 在钩子之后才按面板重算。账完成且没有新短款时，才重试被挡住的结局前窗口。
		if _open_due_pre_ending(ctx):
			return {"ok": true, "err": "", "next_phase": str(loop["phase"])}
	if str(loop.get("phase", "")) == "game_over":
		return {"ok": true, "err": ""}
	var next := int(loop.get("stage", 0)) + 1
	if ctx.db.stage(next).is_empty():
		finish_game(ctx, "ending")
	else:
		set_phase(ctx, CardIds.PH_YEAR_JUMP)
		CardFirsts.mark(ctx, &"year_jump", {})
	return {"ok": true, "err": ""}


## 月账确认完成之后：若末关曾因短款记下 pre_ending_due，此时 pending 已是钩子之后的新值。
## 打开窗口并通知主人发牌。不在这里清 pending，也不再跑一遍 month_close。
static func _open_due_pre_ending(ctx: CardCtx) -> bool:
	var loop := ctx.state.ns("loop")
	var due := str(loop.get("pre_ending_due", ""))
	if due == "":
		return false
	if str(loop.get("phase", "")) != str(CardIds.PH_MONTH_CLOSE):
		return false
	if not open_pre_ending_window(ctx, due):
		return false
	ctx.hooks.fire(ctx, &"pre_ending_window", {"owner": due})
	return str(loop.get("phase", "")) != "month_close"


static func jump_year(ctx: CardCtx) -> Dictionary:
	if str(ctx.state.ns("loop").get("phase", "")) != "year_jump":
		return {"ok": false, "err": CardIds.ERR_BAD_PHASE}
	var result := CardYearJump.run(ctx)
	if not bool(result.get("ok", false)):
		return result
	if str(ctx.state.ns("loop").get("phase", "")) != "game_over":
		begin_stage(ctx, int(ctx.state.ns("loop")["stage"]) + 1)
		open_month(ctx)
	return {"ok": true, "err": ""}

static func finish_game(ctx: CardCtx, reason: String) -> void:
	ctx.state.ns("loop")["reason"] = reason
	set_phase(ctx, CardIds.PH_GAME_OVER)
	ctx.emit(&"game_over", [StringName(reason)])
	CardFirsts.mark(ctx, &"game_over", {"kind": reason})

static func set_phase(ctx: CardCtx, phase: StringName) -> void:
	var loop := ctx.state.ns("loop")
	var from := StringName(str(loop.get("phase", CardIds.PH_BOOT)))
	loop["phase"] = str(phase)
	if from != phase:
		ctx.emit(&"phase_changed", [from, phase])

static func advance_minutes(ctx: CardCtx, minutes: int) -> void:
	var loop := ctx.state.ns("loop")
	loop["minute"] = int(loop.get("minute", 480)) + minutes

static func request_panel(ctx: CardCtx, kind: StringName, args: Dictionary) -> void:
	ctx.state.ns("loop")["open_panel"] = {"kind": str(kind), "args": args.duplicate(true)}
	ctx.emit(&"request_panel", [kind, args.duplicate(true)])

static func set_mode(ctx: CardCtx, mode: StringName) -> void:
	ctx.state.ns("loop")["mode"] = str(mode)

