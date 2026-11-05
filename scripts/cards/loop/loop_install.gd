# G02 模块登记：循环指令、查询、效果与条件，以及合同指定的生命周期监听。
# 存档恢复时保留 ui 并集、指令日志与开放面板，账本缓存随状态失效。
class_name CardLoopInstall
extends RefCounted

const OWNER := "G02"
const Reports = preload("res://scripts/cards/loop/loop_reports.gd")
const EndRules = preload("res://scripts/cards/loop/end_day_rules.gd")
const _LegacyInstall = preload("res://scripts/cards/legacy/legacy_install.gd")

static func install(engine: CardEngine, ctx: CardCtx) -> void:
	var weak: WeakRef = weakref(engine)
	engine.register_command(&"game.new", _cmd_new.bind(weak), OWNER)
	engine.register_command(&"game.save", _cmd_save.bind(weak), OWNER)
	engine.register_command(&"game.load", _cmd_load.bind(weak), OWNER)
	engine.register_command(&"game.retry_stage", _cmd_retry.bind(weak), OWNER)
	for cmd in [&"month.begin", &"day.begin", &"day.end", &"night.choose", &"settle.next", &"month.next", &"year.next"]:
		engine.register_command(cmd, _cmd_progress.bind(cmd), OWNER)
	engine.register_query(&"card", _q_card, OWNER)
	engine.register_query(&"actions", _q_actions, OWNER)
	engine.register_query(CardIds.Q_DAY_END_PREVIEW, _q_end_preview, OWNER)
	for q in [&"settle_report", &"month_report", &"year_report"]:
		engine.register_query(q, _q_report.bind(q), OWNER)
	for op in [&"day_gte", &"abs_day_gte", &"weekday", &"era", &"stage_gte", &"mode", &"phase", &"goal_status"]:
		ctx.conds.register(op, _cond.bind(op), CardDslShapes.shape(op, true), OWNER)
	for op in [&"goal", &"game_over"]:
		ctx.ops.register(op, _op.bind(op), CardDslShapes.shape(op), OWNER)
	ctx.mods.register(&"hand_sub", _mod_hand_sub, OWNER)
	ctx.mods.register(&"scheduled_cards", _mod_scheduled, OWNER)
	ctx.mods.register(&"end_rows", EndRules.own_rows, OWNER)
	ctx.hooks.on(CardIds.HOOK_STAGE_START, _hook_stage, 40, OWNER)
	ctx.hooks.on(CardIds.HOOK_CARD_RESOLVED, _hook_resolved, 20, OWNER)
	ctx.hooks.on(CardIds.HOOK_DAY_END, _hook_end, 10, OWNER)
	ctx.hooks.on(CardIds.HOOK_SETTLE, _hook_settle, 70, OWNER)
	ctx.hooks.on(CardIds.HOOK_MONTH_CLOSE, _hook_month, 20, OWNER)
	ctx.hooks.on(CardIds.HOOK_YEAR_JUMP, CardYearJump.contacts, 40, OWNER)

static func _cmd_new(ctx: CardCtx, opts: Dictionary, weak: WeakRef) -> Dictionary:
	for key in ["seed", "stage"]:
		if opts.has(key) and typeof(opts[key]) != TYPE_INT:
			return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	# Rogue v1 (ROGUE_V1.md §4.1): optional run context from the shell; absent or {} keeps today's state byte for byte.
	if opts.has("run") and typeof(opts["run"]) != TYPE_DICTIONARY:
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	var db := CardDB.load_all(str(opts.get("data_root", CardDB.DEFAULT_ROOT)),
		{"only_examples": bool(opts.get("only_examples", false)), "ship": CardShip.is_ship()})
	if db.stage(int(opts.get("stage", 0))).is_empty() or not db.errors().is_empty():
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	var run: Dictionary = opts.get("run", {})
	var run_err: String = _LegacyInstall.check_run(db, run)
	if run_err != "":
		return {"ok": false, "err": run_err}
	ctx.db = db
	CardText.setup(db)
	CardSave.set_root(str(opts.get("save_dir", CardSave.LEGACY_ROOT)))
	ctx.state = CardState.create(int(opts.get("seed", 0)), {"difficulty": str(opts.get("difficulty", "normal")), "db_hash": db.hash()})
	ctx.ledger = null
	_LegacyInstall.init_run(ctx, run)
	var engine: CardEngine = weak.get_ref()
	engine.clear_command_log()
	CardDayLoop.begin_stage(ctx, int(opts.get("stage", 0)))
	CardDayLoop.open_month(ctx)
	return {"ok": true, "err": ""}

static func _cmd_save(ctx: CardCtx, args: Dictionary, weak: WeakRef) -> Dictionary:
	if str(ctx.state.ns("loop").get("phase", "")) not in ["morning", "month_open"]:
		return {"ok": false, "err": CardIds.ERR_BAD_PHASE}
	if args.has("path") and (typeof(args["path"]) != TYPE_STRING or str(args["path"]) == ""):
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	var engine: CardEngine = weak.get_ref()
	var path := str(args.get("path", CardSave.suspend_path()))
	var res := CardSave.write(path, ctx.state, {"stage": int(ctx.state.ns("loop").get("stage", 0)),
		"abs_day": ctx.abs_day(), "cmd_log": engine.command_log()})
	ctx.emit(&"saved", [path, bool(res["ok"])])
	return res

static func _cmd_load(ctx: CardCtx, args: Dictionary, weak: WeakRef) -> Dictionary:
	if args.has("path") and (typeof(args["path"]) != TYPE_STRING or str(args["path"]) == ""):
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	var path := str(args.get("path", CardSave.suspend_path()))
	var remembered := CardFirsts.all(ctx) if ctx.state != null else {}
	var res := CardSave.read(path)
	if not bool(res["ok"]):
		return res
	if int((res["state"] as CardState).ns("loop").get("_v", 0)) > 1:
		return {"ok": false, "err": CardIds.ERR_SAVE_NEWER}
	var engine: CardEngine = weak.get_ref()
	var st: CardState = res["state"]
	if ctx.db == null:
		ctx.db = CardDB.load_all(CardDB.DEFAULT_ROOT, {})
		CardText.setup(ctx.db)
	var meta: Dictionary = res["meta"]
	meta["db_changed"] = str(res.get("db_hash", "")) != ctx.db.hash()
	if ctx.state != null:
		st.data["ui"] = CardCoreInstall.merge_ui(ctx.state.ns("ui"), st.ns("ui"))
	ctx.state = st
	ctx.ledger = null
	_migrate(ctx)
	engine.restore_command_log(res.get("cmd_log", []))
	# System firsts survive rewinding an older snapshot; their hash exceptions are documented.
	for mechanism in [&"retry", &"resume"]:
		if remembered.has(str(mechanism)): _mark_restored(ctx, mechanism, true)
	if path == CardSave.suspend_path():
		_mark_restored(ctx, &"resume", remembered.has("resume"))
	_restore_panel(ctx)
	return {"ok": true, "err": "", "meta": meta}

static func _cmd_retry(ctx: CardCtx, args: Dictionary, weak: WeakRef) -> Dictionary:
	if not args.is_empty():
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	var seen := CardFirsts.all(ctx).has("retry")
	var res := _cmd_load(ctx, {"path": CardSave.stage_path(int(ctx.state.ns("loop").get("stage", 0)))}, weak)
	if bool(res.get("ok", false)):
		CardDayLoop.set_phase(ctx, CardIds.PH_MONTH_OPEN)
		_mark_restored(ctx, &"retry", seen)
	return res

static func _cmd_progress(ctx: CardCtx, args: Dictionary, cmd: StringName) -> Dictionary:
	if cmd == &"day.end":
		if str(ctx.state.ns("loop").get("phase", "")) not in EndRules.STEPS:
			return {"ok": false, "err": CardIds.ERR_BAD_PHASE}
		if args.keys().any(func(key: Variant) -> bool:
			return str(key) != "confirm"):
			return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
		for key in args:
			if typeof(args[key]) != TYPE_BOOL: return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
		return CardDayLoop.end_day(ctx, bool(args.get("confirm", false)))
	var phases := {&"month.begin": "month_open", &"day.begin": "morning", &"night.choose": "night",
		&"settle.next": "settle", &"month.next": "month_close", &"year.next": "year_jump"}
	if str(ctx.state.ns("loop").get("phase", "")) != str(phases[cmd]):
		return {"ok": false, "err": CardIds.ERR_BAD_PHASE}
	if cmd == &"night.choose":
		if typeof(args.get("def")) != TYPE_STRING or typeof(args.get("choice", "")) != TYPE_STRING:
			return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
		return CardDayLoop.choose_night_choice(ctx, str(args["def"]), str(args.get("choice", "")))
	if not args.is_empty():
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	match cmd:
		&"month.begin":
			var panel: Dictionary = ctx.state.ns("loop").get("open_panel", {})
			if str(panel.get("kind", "")) == "wheel" and bool(panel.get("args", {}).get("required", false)) and str(ctx.state.ns("fate").get("month_segment", "")) == "":
				return {"ok": false, "err": "wheel_pending"}
			CardDayLoop.enter_morning(ctx)
			return {"ok": true, "err": ""}
		&"day.begin":
			return CardDayLoop.begin_day(ctx)
		&"settle.next":
			return CardDayLoop.settle(ctx)
		&"month.next":
			return CardDayLoop.close_month(ctx)
		&"year.next":
			return CardDayLoop.jump_year(ctx)
	return {"ok": false, "err": CardIds.ERR_BAD_ARGS}

static func _q_card(ctx: CardCtx, args: Dictionary) -> Dictionary:
	var v := CardViewModel.card_view(ctx, str(args.get("uid", "")), true)
	return v if not v.is_empty() else {"ok": false, "err": CardIds.ERR_UNKNOWN_UID}

static func _q_actions(ctx: CardCtx, args: Dictionary) -> Dictionary:
	return {"actions": ctx.actions.for_card(ctx, str(args.get("uid", "")))}

static func _q_end_preview(ctx: CardCtx, _args: Dictionary) -> Dictionary:
	var result := EndRules.preview(ctx)
	assert(CardViewModel.leaks(result).is_empty(), "Visible end preview contains hidden keys")
	return result

static func _q_report(ctx: CardCtx, _args: Dictionary, q: StringName) -> Dictionary:
	return (ctx.state.ns("loop").get("reports", {}).get(str(q).trim_suffix("_report"), {"lines": []}) as Dictionary).duplicate(true)

static func _mod_hand_sub(ctx: CardCtx, args: Dictionary) -> int:
	return CardGoldRule.hand_sub(ctx, str(args.get("uid", "")))

static func _mod_scheduled(ctx: CardCtx, args: Dictionary) -> Array:
	return Array(CardSchedule.due(ctx, int(args.get("abs_day", 0))))

static func _cond(ctx: CardCtx, value: Variant, op: StringName) -> bool:
	var loop := ctx.state.ns("loop")
	match op:
		&"day_gte": return int(loop.get("stage_day", 0)) >= int(value)
		&"abs_day_gte": return ctx.abs_day() >= int(value)
		&"weekday": return int(CardCalendar.today(ctx)["weekday"]) == int(value)
		&"era": return str(ctx.db.stage(int(loop.get("stage", 0))).get("era", "")) == str(value)
		&"stage_gte": return int(loop.get("stage", 0)) >= int(value)
		&"mode": return str(loop.get("mode", "shop")) == str(value)
		&"phase": return str(loop.get("phase", "")) == str(value)
		&"goal_status":
			for row in loop.get("goals", []):
				if str(row.get("id", "")) == str(value[0]):
					return str(row.get("status", "open")) == str(value[1])
	return false

static func _op(ctx: CardCtx, eff: Dictionary, _source: String, op: StringName) -> void:
	if op == &"goal":
		CardGoals.set_status(ctx, str(eff.get("id", "")), str(eff.get("status", "")))
	else:
		CardDayLoop.finish_game(ctx, str(eff.get("reason", "")))

static func _hook_stage(ctx: CardCtx, _args: Dictionary) -> void:
	CardGoals.pick(ctx)

static func _hook_resolved(ctx: CardCtx, _args: Dictionary) -> void:
	CardGoals.evaluate(ctx, &"any_time")

static func _hook_end(ctx: CardCtx, _args: Dictionary) -> void:
	EndRules.execute_owned(ctx)

static func _hook_settle(ctx: CardCtx, _args: Dictionary) -> void:
	var start := 0
	for i in range(ctx.out.size() - 1, -1, -1):
		var event: Array = ctx.out[i]
		if event.size() >= 3 and StringName(event[0]) == &"phase_changed" and str(event[2]) == "settle":
			start = i + 1
			break
	# The caller finalizes once more after the hook chain, retaining notices from later extension listeners.
	Reports.finish_settle(ctx, start)

static func _hook_month(ctx: CardCtx, _args: Dictionary) -> void:
	CardGoals.evaluate(ctx, &"month_close")

static func _migrate(ctx: CardCtx) -> void:
	var loop := ctx.state.ns("loop")
	if int(loop.get("_v", 0)) >= 1:
		return
	loop.merge({"_v": 1, "notices": [], "sched_done": {}, "reason": "", "morning_snapshot": {},
		"gold_left": [], "reports": {"settle": {"lines": []}, "month": {"lines": []}, "year": {"lines": []}}}, false)
	for section in ["settle", "month", "year"]:
		if not loop["reports"].has(section): loop["reports"][section] = {"lines": []}
		elif typeof(loop["reports"][section]) == TYPE_DICTIONARY:
			loop["reports"][section].merge({"lines": []}, false)


static func _mark_restored(ctx: CardCtx, mechanism: StringName, already_seen: bool) -> void:
	var start := ctx.out.size()
	CardFirsts.mark(ctx, mechanism, {})
	if already_seen:
		ctx.out.resize(start)


static func _restore_panel(ctx: CardCtx) -> void:
	var loop := ctx.state.ns("loop")
	var panel: Dictionary = loop.get("open_panel", {})
	var fate := ctx.state.ns("fate")
	var completed: Dictionary = fate.get("wheels", {}).get("wh.month:", {}).get("result", {})
	var needs_month := str(loop.get("phase", "")) == "month_open" and str(panel.get("kind", "")) == ""
	needs_month = needs_month and str(fate.get("month_segment", "")) == "" and completed.is_empty()
	if needs_month and ctx.db.has("wh.month") and not ctx.hooks.listeners(CardIds.HOOK_MONTH_OPEN).is_empty():
		# Old W0 saves predate the required panel. Delegate its first and request to G05 without re-spinning.
		ctx.hooks.fire(ctx, CardIds.HOOK_MONTH_OPEN, {})
	elif str(panel.get("kind", "")) != "":
		CardDayLoop.request_panel(ctx, StringName(str(panel["kind"])), panel.get("args", {}))
