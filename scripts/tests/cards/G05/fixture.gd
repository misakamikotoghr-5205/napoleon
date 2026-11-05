# G05 的 W0 独立测试夹具；跨模块服务使用窄接口替身。
# 正文只用 ASCII，不改共享数据与登记表实现。
extends RefCounted

static func db() -> CardDB:
	var db := CardDB.load_all(CardDB.DEFAULT_ROOT, {"only_examples": true})
	for grade in range(5):
		add(db, {"id": "lot.test.%d" % grade, "type": "fortune_lot", "era": ["*"], "weight": 100, "grade": grade, "hint_tags": []})
	add(db, {"id": "ev.test.fortune", "type": "event", "era": ["*"], "weight": 0, "opens_fortune": "both", "cost": {"money": 0}, "tags": ["omen_official"]})
	add(db, {"id": "ev.test.fortune_lot", "type": "event", "era": ["*"], "weight": 0, "opens_fortune": "lot", "cost": {"money": 0}, "tags": []})
	add(db, {"id": "ev.test.fortune_cezi", "type": "event", "era": ["*"], "weight": 0, "opens_fortune": "cezi", "cost": {"money": 0}, "tags": []})
	add(db, {"id": "ev.test.wheel", "type": "event", "era": ["*"], "weight": 0, "opens_wheel": "wh.fair", "tags": []})
	for i in range(6):
		add(db, {"id": "ev.test.%d" % i, "type": "event", "era": ["*"], "weight": 100,
			"tags": ["omen_official", "bad_omen"] if i < 3 else ["omen_water"]})
	add(db, {"id": "cz.test.empty", "type": "cezi", "era": ["*"], "weight": 10, "tags": ["omen_illness"]})
	for wheel in ["wh.fair", "wh.gamble"]:
		for i in range(3):
			add(db, {"id": "ws.test.%s.%d" % [wheel, i], "type": "wheel_segment", "wheel": wheel, "era": ["1938"],
				"arc": 2 + i, "valence": ["good", "neutral", "bad"][i], "effects": [], "weight": 0, "art": "TXT_ART"})
	var deal: Dictionary = db._rules["deal"]
	deal["scripted_days"] = {}
	return db

static func add(db: CardDB, def: Dictionary) -> void:
	var id := str(def["id"])
	var type := str(def["type"])
	db._order[id] = db._cards.size()
	db._cards[id] = def.duplicate(true)
	if not db._by_type.has(type):
		db._by_type[type] = []
	(db._by_type[type] as Array).append(id)
	(db._by_type[type] as Array).sort()

static func ctx(db: CardDB, seed: int = 0) -> CardCtx:
	var engine := CardEngine.new()
	var ctx := engine.ctx
	ctx.db = db
	ctx.state = CardState.create(seed, {})
	ctx.state.ns("loop").merge({"phase": "day", "mode": "shop", "stage": 0, "stage_day": 5, "abs_day": 5, "minute": 480})
	ctx.state.ns("econ")["ledger"] = {"accounts": {"player": 1000}}
	ctx.state.ns("rules")["meters"] = {"rep": 20, "heat": 0, "conscience": 0}
	ctx.conds._conds[&"conscience_gte"]["fn"] = _conscience_gte
	ctx.ops._ops[&"pay"]["handler"] = _pay
	ctx.ops._ops[&"rep"]["handler"] = _rep
	ctx.ops._ops[&"extra_deal"]["handler"] = _extra_deal
	_isolate_loop_hooks(ctx)
	return ctx

static func _isolate_loop_hooks(ctx: CardCtx) -> void:
	# 独立夹具不运行 G02 的阶段/报告协议；仍保留其只读修正项。
	for name in ctx.hooks._hooks:
		ctx.hooks._hooks[name] = (ctx.hooks._hooks[name] as Array).filter(
			func(handler: Dictionary) -> bool: return str(handler["owner"]) != "G02")

static func _conscience_gte(ctx: CardCtx, threshold: int) -> bool:
	return int(ctx.state.ns("rules")["meters"]["conscience"]) >= threshold

static func _pay(ctx: CardCtx, effect: Dictionary, _source: String) -> void:
	var accounts: Dictionary = ctx.state.ns("econ")["ledger"]["accounts"]
	accounts["player"] = int(accounts["player"]) - int(effect["amount"])

static func _rep(ctx: CardCtx, effect: Dictionary, _source: String) -> void:
	var meters: Dictionary = ctx.state.ns("rules")["meters"]
	meters["rep"] = int(meters["rep"]) + int(effect.get("delta", 0))

static func fortune_uid(ctx: CardCtx) -> String:
	return CardPiles.spawn(ctx, "ev.test.fortune", CardIds.ZONE_HAND)

static func wheel_uid(ctx: CardCtx, wheel: String) -> String:
	return CardPiles.spawn(ctx, "ev.any.wheel_go", CardIds.ZONE_HAND, {"vars": {"wheel": wheel, "cost": ctx.db.def(wheel).get("cost", {})}})

static func card_uid(ctx: CardCtx, def_id: String) -> String:
	return CardPiles.spawn(ctx, def_id, CardIds.ZONE_HAND)

static func advance(ctx: CardCtx, day: int) -> void:
	ctx.state.ns("loop")["abs_day"] = day
	ctx.state.ns("loop")["stage_day"] = day

static func _extra_deal(ctx: CardCtx, effect: Dictionary, _source: String) -> void:
	ctx.state.ns("core")["test_extra_deal"] = effect.duplicate(true)

