# Rogue v1 stocktake: registration only. Owner RG2. Installed after relics (card_engine.gd). No class_name.
# Command stock.pick, query stocktake, op stock_offer, modifiers pool_pct / deal_count / view_section (key "stock"),
# hooks stage_start 60, day_start 3, card_resolved 35, settle 80 (docs/cards/rogue/ROGUE_V1.md §4.2-§4.6).
# With no rules/stock.json (or enabled false, or no sources and no relics) nothing here writes state.
extends RefCounted

const Ids = preload("res://scripts/cards/stock/stock_ids.gd")
const Offers = preload("res://scripts/cards/stock/stock_offers.gd")
const Pick = preload("res://scripts/cards/stock/stock_pick.gd")
const Mods = preload("res://scripts/cards/stock/stock_mods.gd")
const View = preload("res://scripts/cards/stock/stock_view.gd")


static func install(engine: CardEngine, ctx: CardCtx) -> void:
	engine.register_command(Ids.CMD_PICK, _cmd_pick, Ids.OWNER)
	engine.register_query(Ids.Q_STOCKTAKE, _q_stocktake, Ids.OWNER)
	ctx.ops.register(Ids.OP_OFFER, _op_offer, CardDslShapes.shape(Ids.OP_OFFER), Ids.OWNER)
	ctx.mods.register(&"pool_pct", Mods.pool_pct, Ids.OWNER)
	ctx.mods.register(&"deal_count", Mods.deal_count, Ids.OWNER)
	ctx.mods.register(&"view_section", View.section, Ids.OWNER)
	ctx.hooks.on(CardIds.HOOK_STAGE_START, Offers.on_stage_start, Ids.PRI_STAGE_START, Ids.OWNER)
	ctx.hooks.on(CardIds.HOOK_DAY_START, Offers.on_day_start, Ids.PRI_DAY_START, Ids.OWNER)
	ctx.hooks.on(CardIds.HOOK_CARD_RESOLVED, Offers.on_resolved, Ids.PRI_RESOLVED, Ids.OWNER)
	ctx.hooks.on(CardIds.HOOK_SETTLE, Offers.on_settle, Ids.PRI_SETTLE, Ids.OWNER)


static func _cmd_pick(ctx: CardCtx, args: Dictionary) -> Dictionary:
	return Pick.pick(ctx, args)


static func _q_stocktake(ctx: CardCtx, args: Dictionary) -> Dictionary:
	return View.query(ctx, args)


static func _op_offer(ctx: CardCtx, eff: Dictionary, source: String) -> void:
	Offers.op_offer(ctx, eff, source)
