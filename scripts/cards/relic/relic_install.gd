# Rogue v1 relics: registration only. Owner RG1. Installed after K18 (card_engine.gd). No class_name.
# Registers the "relics" query, the "relics" view block, the seven modifier providers and the two hooks
# (docs/cards/rogue/ROGUE_V1.md §4.3–§4.6). No command: relics are taken through relic_api.gd (RG2's stock.pick).
extends RefCounted

const Ids = preload("res://scripts/cards/relic/relic_ids.gd")
const Mods = preload("res://scripts/cards/relic/relic_mods.gd")
const Hooks = preload("res://scripts/cards/relic/relic_hooks.gd")
const View = preload("res://scripts/cards/relic/relic_view.gd")


static func install(engine: CardEngine, ctx: CardCtx) -> void:
	engine.register_query(Ids.Q_RELICS, _q_relics, Ids.OWNER)
	ctx.mods.register(&"view_section", View.section, Ids.OWNER)
	Mods.install(ctx)
	Hooks.install(ctx)


static func _q_relics(ctx: CardCtx, args: Dictionary) -> Dictionary:
	return View.query(ctx, args)
