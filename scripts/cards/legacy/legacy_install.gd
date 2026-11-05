# Rogue v1 run context: registration plus the two calls CardLoopInstall._cmd_new makes. Owner RG5. No class_name.
# docs/cards/rogue/ROGUE_V1.md §4.1 (game.new {run}), §4.3 (legacy.harvest, legacy.old_ink), §4.4 (veteran,
# unscripted_day), §4.5 (view_section run), §4.6 (day_start 2). Installed last (card_engine.gd); never reorder.
extends RefCounted

const Ids = preload("res://scripts/cards/legacy/legacy_ids.gd")
const Run = preload("res://scripts/cards/legacy/legacy_run.gd")
const Harvest = preload("res://scripts/cards/legacy/legacy_harvest.gd")


static func install(engine: CardEngine, ctx: CardCtx) -> void:
	engine.register_query(Ids.Q_HARVEST, _q_harvest, Ids.OWNER)
	engine.register_query(Ids.Q_OLD_INK, _q_old_ink, Ids.OWNER)
	ctx.conds.register(Ids.COND_VETERAN, _cond_veteran, CardDslShapes.shape(Ids.COND_VETERAN, true), Ids.OWNER)
	ctx.mods.register(Ids.MOD_UNSCRIPTED, Run.mod_unscripted, Ids.OWNER)
	ctx.mods.register(&"view_section", Run.view_section, Ids.OWNER)
	ctx.hooks.on(CardIds.HOOK_DAY_START, Run.on_day_start, Ids.DAY_START_PRIORITY, Ids.OWNER)


## Before the state exists. "" = ok, otherwise an error code (bad_args).
static func check_run(db: CardDB, run: Dictionary) -> String:
	return Run.check_run(db, run)


## Right after CardState.create, before begin_stage. An empty run writes nothing (zero identity).
static func init_run(ctx: CardCtx, run: Dictionary) -> void:
	Run.init_run(ctx, run)


static func _q_harvest(ctx: CardCtx, args: Dictionary) -> Dictionary:
	return Harvest.harvest(ctx, args)


static func _q_old_ink(ctx: CardCtx, args: Dictionary) -> Dictionary:
	return Harvest.old_ink(ctx, args)


static func _cond_veteran(ctx: CardCtx, value: Variant) -> bool:
	return Run.cond_veteran(ctx, value)
