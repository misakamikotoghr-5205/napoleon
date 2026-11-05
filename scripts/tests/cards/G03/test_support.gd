# G03 的 W1 测试替身；钱和 arrest 使用独立登记，不依赖其他线。
# 测试数据仅 ASCII 假字，规则数据和牌堆仍用 W0 公共实现。
extends RefCounted
const H = preload("res://scripts/cards/rules/rules_helpers.gd")

static func engine(seed: int = 7) -> CardEngine:
	var e := CardEngine.new()
	var ctx := e.ctx
	ctx.db = CardDB.load_all("res://data/cards", {"only_examples": true})
	ctx.state = CardState.create(seed, {"db_hash": ctx.db.hash()})
	ctx.state.ns("loop").merge({"phase": "morning", "stage": 0, "stage_day": 1, "abs_day": 1}, true)
	ctx.ops = CardOps.new()
	ctx.conds = CardConds.new()
	ctx.mods = CardMods.new()
	ctx.hooks = CardHooks.new()
	ctx.actions = CardActions.new()
	CardRulesInstall._install_ctx(ctx)
	for op in CardDslShapes.EFFECT_OPS.keys():
		if CardDslShapes.EFFECT_OPS[op] != "G03": ctx.ops.register(op, effect.bind(op), CardDslShapes.shape(op), "TEST")
	for op in CardDslShapes.COND_OPS.keys():
		if CardDslShapes.COND_OPS[op] != "G03": ctx.conds.register(op, condition.bind(op), CardDslShapes.shape(op, true), "TEST")
	CardMeters.initialize(ctx)
	H.state(ctx)["test_money"] = 500
	return e

static func effect(ctx: CardCtx, eff: Dictionary, source: String, op: StringName) -> void:
	var r := H.state(ctx)
	match op:
		&"pay": r["test_money"] = maxi(0, int(r["test_money"]) - int(eff["amount"]))
		&"money": r["test_money"] = int(r["test_money"]) + int(eff["delta"])
		&"add_card": CardPiles.spawn(ctx, str(eff["card"]), StringName(eff["to"]))
		&"arrest", &"shop_closed", &"estate_seize":
			if not r.has("test_effects"): r["test_effects"] = []
			(r["test_effects"] as Array).append({"op": str(op), "source": source})

static func condition(ctx: CardCtx, value, op: StringName) -> bool:
	match op:
		&"money_gte": return int(H.peek(ctx).get("test_money", 0)) >= int(value)
		&"money_lt": return int(H.peek(ctx).get("test_money", 0)) < int(value)
	return false

static func card(ctx: CardCtx, id: String, d: Dictionary, zone: StringName = &"hand") -> String:
	d["id"] = id
	ctx.db._cards[id] = d.duplicate(true)
	var type := str(d.get("type", "event"))
	if not ctx.db._by_type.has(type): ctx.db._by_type[type] = []
	if not (ctx.db._by_type[type] as Array).has(id): (ctx.db._by_type[type] as Array).append(id)
	(ctx.db._by_type[type] as Array).sort()
	return CardPiles.spawn(ctx, id, zone)

static func event(ctx: CardCtx, need: int = 1) -> String:
	return card(ctx, "ev.test", {"type": "event", "slots": [{"id": "man", "accepts": ["self", "contact"], "attr": "eye"}, {"id": "cash", "accepts": ["money"]}, {"id": "kept", "accepts": ["kept"], "tags": ["official", "papers", "family"]}, {"id": "news", "accepts": ["news"]}], "check": {"need": need, "on_success": [{"op": "flag", "key": "success"}], "on_fail": [{"op": "flag", "key": "failure"}]}})

static func fragment(ctx: CardCtx, id: String, person: String, kind: String = "said", previous: String = "", era: Array = ["*"]) -> void:
	card(ctx, id, {"type": "dossier_fragment", "person": person, "kind": kind, "order": 1, "era": era, "year_after_of": previous}, &"discard")

static func clone(e: CardEngine) -> CardEngine:
	var other := engine(int(e.ctx.state.data["seed"]))
	other.ctx.db = e.ctx.db
	other.ctx.state = CardState.from_dict(e.ctx.state.to_dict())
	return other
