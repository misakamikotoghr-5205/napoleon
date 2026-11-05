# 阶梯单测的独立 W0 替身；钱款登记假的 op，不依赖其他线的实现进度。
# G06；合同 §12.1、任务卡 W1-a 测试替身。
extends RefCounted


static func engine() -> CardEngine:
	var e: CardEngine = CardEngine.new()
	e.ctx.db = CardDB.load_all("res://data/cards", {"only_examples": true})
	e.ctx.state = CardState.create(7, {"db_hash": e.ctx.db.hash()})
	e.ctx.ops = CardOps.new()
	e.ctx.conds = CardConds.new()
	e.ctx.hooks = CardHooks.new()
	e.ctx.hooks.on(&"stage_start", CardMortgage._stage_start, 15, "G06")
	e.ctx.hooks.on(&"month_close", CardLadderInstall._month_close, 15, "G06")
	e.ctx.hooks.on(&"money_short", CardShortLadder.on_short, 5, "G06")
	e.ctx.hooks.on(&"day_end", CardShortLadder._day_end, 7, "G06")
	e.ctx.hooks.on(&"day_end", CardPrison._day_end, 25, "G06")
	e.ctx.hooks.on(&"card_resolved", CardPrison._resolved, 15, "G06")
	for op in [&"money", &"pay", &"game_over", &"shop_closed"]:
		e.ctx.ops.register(op, _effect.bind(op), CardDslShapes.shape(op), "G06_test")
	for op in [&"arrest", &"estate_seize"]:
		e.ctx.ops.register(op, CardLadderInstall._effect.bind(op), CardDslShapes.shape(op), "G06")
	e.ctx.conds.register(&"money_gte", _money_gte, CardDslShapes.shape(&"money_gte", true), "G06_test")
	e.ctx.conds.register(&"estate_status", CardLadderInstall._estate_status,
		CardDslShapes.shape(&"estate_status", true), "G06")
	CardDayLoop.begin_stage(e.ctx, 0)
	e.ctx.state.ns("loop")["phase"] = "day"
	e.ctx.state.ns("loop")["abs_day"] = 1
	e.ctx.state.ns("econ")["test_money"] = 1000
	e.ctx.out = []
	return e


static func _money_gte(ctx: CardCtx, amount: Variant) -> bool:
	return int(ctx.state.ns("econ").get("test_money", 0)) >= int(amount)


static func _effect(ctx: CardCtx, effect: Dictionary, source: String, op: StringName) -> void:
	var econ: Dictionary = ctx.state.ns("econ")
	var amount: int = int(econ.get("test_money", 0))
	if op == &"money":
		econ["test_money"] = amount + int(effect.get("delta", 0))
	elif op == &"pay":
		var due: int = int(effect.get("amount", 0))
		if amount >= due:
			econ["test_money"] = amount - due
		elif str(effect.get("short", "")) == "ladder":
			ctx.hooks.fire(ctx, &"money_short", {"amount": due, "payee": effect.get("payee", ""), "source": source})
		else:
			econ["default_source"] = source
	elif op == &"shop_closed":
		econ["shop_closed_until"] = ctx.abs_day() + int(effect.get("days", 0))
	else:
		CardDayLoop.set_phase(ctx, &"game_over")
		ctx.emit(&"game_over", [str(effect.get("reason", ""))])


static func count_first(ctx: CardCtx, mech: String) -> int:
	var count: int = 0
	for event in ctx.out:
		if str(event[0]) == "first_time" and str(event[1]) == mech:
			count += 1
	return count
