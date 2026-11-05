# G05 的指令、查询、DSL、修正项与生命周期钩子登记。
# 只写 fate；发牌、付钱、人脉消耗和面板交给各自模块。
class_name CardFateInstall
extends RefCounted
const OWNER := "G05"

static func install(engine: CardEngine, ctx: CardCtx) -> void:
	for cmd in [&"wheel.offer", &"wheel.withdraw", &"wheel.stake", &"wheel.spin", &"fortune.lot", &"fortune.cezi"]:
		engine.register_command(cmd, _command.bind(cmd), OWNER)
	for query in [&"wheel", &"fortune", &"almanac"]:
		engine.register_query(query, _query.bind(query), OWNER)
	for op in CardDslShapes.EFFECT_OPS.keys():
		if CardDslShapes.EFFECT_OPS[op] == OWNER:
			ctx.ops.register(op, _effect.bind(op), CardDslShapes.shape(op), OWNER)
	for op in CardDslShapes.COND_OPS.keys():
		if CardDslShapes.COND_OPS[op] == OWNER:
			ctx.conds.register(op, _condition.bind(op), CardDslShapes.shape(op, true), OWNER)
	for kind in [&"pool_rows", &"pinned_cards", &"fate_due", &"price_pct", &"view_section", &"card_view_part", &"end_rows"]:
		ctx.mods.register(kind, _mod.bind(kind), OWNER)
	ctx.mods.register(&"deal_count", CardWeights.deal_count, OWNER)
	for pair in [[&"stage_start", 30], [&"month_open", 10], [&"day_start", 10], [&"deal_composed", 30],
		[&"card_resolved", 10], [&"night_chosen", 10], [&"day_end", 15], [&"settle", 50], [&"settle", 60], [&"money_short", 10], [&"arrested", 10]]:
		ctx.hooks.on(pair[0], _hook.bind(pair[0], int(pair[1])), int(pair[1]), OWNER)

static func _command(ctx: CardCtx, args: Dictionary, cmd: StringName) -> Dictionary:
	var uid := str(args.get("uid", ""))
	var wheel := str(args.get("wheel", ""))
	if str(cmd).begins_with("wheel.") and (not args.has("wheel") or not args.has("uid")):
		return {"ok": false, "err": "bad_args"}
	if str(cmd).begins_with("wheel.") and uid == "":
		var panel: Dictionary = ctx.state.ns("loop").get("open_panel", {})
		var opened: Dictionary = panel.get("args", {})
		if str(ctx.state.ns("loop").get("phase", "")) != "month_open" or str(panel.get("kind", "")) != "wheel" or str(opened.get("wheel", "")) != wheel or str(opened.get("uid", "")) != uid:
			return {"ok": false, "err": "bad_phase"}
	match cmd:
		&"wheel.offer":
			return CardWheel.offer(ctx, wheel, uid, args.get("source", {})) if typeof(args.get("source")) == TYPE_DICTIONARY else {"ok": false, "err": "bad_args"}
		&"wheel.withdraw":
			return CardWheel.withdraw(ctx, wheel, uid, int(args["index"])) if typeof(args.get("index")) == TYPE_INT else {"ok": false, "err": "bad_args"}
		&"wheel.stake":
			return CardWheel.stake(ctx, wheel, uid, str(args.get("kept_uid", "")))
		&"wheel.spin":
			return CardWheel.spin(ctx, wheel, uid)
		&"fortune.lot":
			return CardFortune.draw_lot(ctx, uid)
		&"fortune.cezi":
			return CardFortune.cezi(ctx, uid, str(args.get("char", "")))
	return {"ok": false, "err": "bad_args"}

static func _query(ctx: CardCtx, args: Dictionary, query: StringName) -> Dictionary:
	match query:
		&"wheel": return CardWheel.view(ctx, str(args.get("wheel", "")), str(args.get("uid", "")))
		&"fortune": return CardFortune.query(ctx, str(args.get("uid", "")))
		&"almanac": return CardAlmanac.today(ctx)
	return {}

static func _effect(ctx: CardCtx, effect: Dictionary, source: String, op: StringName) -> void:
	var fate := ctx.state.ns("fate")
	match op:
		&"deck_mod":
			var mods: Array = fate.get("deck_mods", [])
			var row := effect.duplicate(true)
			row.erase("op")
			row["until_abs_day"] = ctx.abs_day() + maxi(0, int(effect["days"])) - 1
			mods.append(row)
			fate["deck_mods"] = mods
		&"fate_now": ctx.run([{"op": "extra_deal", "type": "fate", "n": 1, "day": str(effect["day"])}], source)
		&"big_wheel": CardFateTrigger.on_crisis(ctx, StringName(str(effect["crisis"])))
		&"wheel_offer":
			var uid := CardPiles.spawn(ctx, "ev.any.wheel_go", CardIds.ZONE_HAND,
				{"vars": {"wheel": str(effect["wheel"]), "cost": effect.get("cost", ctx.db.def(str(effect["wheel"])).get("cost", {}))}})
			card_firsts(ctx, uid)
		&"pressure": CardPressure.influence(ctx, str(effect["key"]), int(effect["delta_milli"]), source)
		&"weather":
			var field := "weather_next" if str(ctx.state.ns("loop").get("phase", "day")) in ["night", "settle"] else "weather"
			fate[field] = str(effect["value"])
		&"peek": CardFortune.peek(ctx, str(effect["pool"]), int(effect.get("n", 1)))

static func _condition(ctx: CardCtx, value, op: StringName) -> bool:
	match op:
		&"weather": return str(ctx.state.ns("fate").get("weather", "clear")) == str(value)
		&"market_day": return CardCalendar.is_market_day(ctx, int(ctx.state.ns("loop").get("stage_day", 0))) == bool(value)
		&"pressure_gte": return CardPressure.value_milli(ctx, str(value[0])) >= int(value[1])
		&"fortune": return str(ctx.state.ns("fate").get("month_segment", "")) == str(value)
		&"almanac_yi": return CardAlmanac.today(ctx)["yi"].has(str(value))
	return false

static func _mod(ctx: CardCtx, args: Dictionary, kind: StringName) -> Variant:
	match kind:
		&"pool_rows": return CardWeights.rows(ctx, StringName(str(args.get("pool", ""))))
		&"pinned_cards": return CardPins.pinned(ctx, int(args.get("abs_day", ctx.abs_day())))
		&"end_rows": return end_rows(ctx)
		&"fate_due": return CardFateTrigger.fate_due(ctx)
		&"view_section": return {"lots": ctx.state.ns("fate").get("lots", []).duplicate(true)}
		&"card_view_part": return _card_part(ctx, str(args.get("uid", "")))
		&"price_pct":
			var pct := 100
			for row in ctx.state.ns("fate").get("month_mods", []):
				if str(row.get("pool", "")) == "price" and (not row.has("direction") or str(row["direction"]) == str(args.get("direction", ""))) and (not row.has("cat") or str(row["cat"]) == str(args.get("cat", ""))):
					pct = pct * int(row.get("pct", 100)) / 100
			return pct
	return null

static func _card_part(ctx: CardCtx, uid: String) -> Dictionary:
	var def := CardPiles.def_of(ctx, uid)
	var part := {"wheel": "", "fortune": ""}
	var wheel := str(CardPiles.card(ctx, uid).get("vars", {}).get("wheel", def.get("opens_wheel", "")))
	part["wheel"] = wheel
	part["fortune"] = str(def.get("opens_fortune", ""))
	if part["fortune"] != "":
		part["cost"] = CardFortune.cost(ctx, uid)
	return part

static func _hook(ctx: CardCtx, args: Dictionary, hook: StringName, priority: int) -> void:
	match hook:
		&"stage_start":
			var fate := ctx.state.ns("fate")
			fate["month_segment"] = ""
			fate["month_mods"] = []
			fate["big"] = {"stage_count": 0, "crises_used": []}
			fate["wheels"] = {}
		&"month_open":
			CardFirsts.mark(ctx, &"month_wheel", {})
			CardDayLoop.request_panel(ctx, &"wheel", {"wheel": "wh.month", "uid": "", "required": true})
		&"day_start":
			CardPins.clear_past(ctx)
			CardPressure.step_day(ctx)
			CardAlmanac.start_day(ctx)
			var crisis := CardFateTrigger.crisis(ctx)
			if crisis in [&"heat_max", &"street_long"]:
				ctx.run([{"op": "big_wheel", "crisis": str(crisis)}], "day_start")
		&"deal_composed":
			for uid in args.get("uids", []):
				card_firsts(ctx, str(uid))
				if str(CardPiles.def_of(ctx, str(uid)).get("type", "")) == "fate":
					ctx.state.ns("fate")["fate_last_abs_day"] = ctx.abs_day()
		&"day_end":
			for row in end_rows(ctx):
				CardPiles.expire(ctx, str(row["uid"]))
			CardWheel.cancel_unspun(ctx)
		&"card_resolved": CardAlmanac.note(ctx, args.get("almanac", []))
		&"night_chosen": CardAlmanac.note(ctx, ctx.db.def(str(args.get("def", ""))).get("almanac", []))
		&"settle":
			if priority == 50:
				CardAlmanac.settle(ctx)
			else:
				_expire_mods(ctx)
		&"money_short": ctx.run([{"op": "big_wheel", "crisis": "cash_short"}], "money_short")
		&"arrested": ctx.run([{"op": "big_wheel", "crisis": "arrested"}], "arrested")

static func _expire_mods(ctx: CardCtx) -> void:
	var keep: Array = []
	for row in ctx.state.ns("fate").get("deck_mods", []):
		if int(row.get("until_abs_day", -1)) > ctx.abs_day():
			keep.append(row)
	ctx.state.ns("fate")["deck_mods"] = keep

static func card_firsts(ctx: CardCtx, uid: String) -> void:
	var def := CardPiles.def_of(ctx, uid)
	var args := {"uid": uid, "def": str(def.get("id", ""))}
	if str(def.get("type", "")) == "fate":
		CardFirsts.mark(ctx, &"fate", args)
	if str(def.get("id", "")) == "bf.wheel":
		CardFirsts.mark(ctx, &"big_wheel", {"uid": uid})
	var opens := str(def.get("opens_fortune", ""))
	if opens in ["lot", "both"]:
		CardFirsts.mark(ctx, &"lot", args)
	if opens in ["cezi", "both"]:
		CardFirsts.mark(ctx, &"cezi", args)
	var wheel := str(CardPiles.card(ctx, uid).get("vars", {}).get("wheel", def.get("opens_wheel", "")))
	if wheel == "wh.fair" or wheel == "wh.gamble":
		CardFirsts.mark(ctx, &"fair_wheel" if wheel == "wh.fair" else &"gamble_wheel", {"uid": uid})
		if bool(CardPiles.card(ctx, uid).get("vars", {}).get("cost", def.get("cost", ctx.db.def(wheel).get("cost", {}))).get("stake", false)):
			CardFirsts.mark(ctx, &"wheel_stake", {"uid": uid})

static func end_rows(ctx: CardCtx) -> Array:
	var rows: Array = []
	for uid in CardPiles.list(ctx, CardIds.ZONE_HAND):
		if str(CardPiles.def_of(ctx, uid).get("id", "")) == "bf.wheel":
			rows.append({"uid": uid, "def": "bf.wheel", "kind": "void", "consequence_key": "g05.end.void", "args": {}})
	return rows

