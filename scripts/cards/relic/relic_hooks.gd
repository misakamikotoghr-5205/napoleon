# Rogue v1 relics: the passives / downsides of held relics on day_start (priority 25, before G03 issues the weekly
# demand at 30, so demand_tier lands on that demand) and settle (priority 45, after G03's daily heat decay at 40).
# Owner RG1 (docs/cards/rogue/ROGUE_V1.md §4.6, §5.4). No class_name. Effects use existing DSL ops only and never draw
# random numbers; a dormant shelf (street / prison) runs nothing.
extends RefCounted

const Ids = preload("res://scripts/cards/relic/relic_ids.gd")
const Api = preload("res://scripts/cards/relic/relic_api.gd")


static func install(ctx: CardCtx) -> void:
	ctx.hooks.on(Ids.HOOK_DAY_START, _day_start, Ids.PRIORITY_DAY_START, Ids.OWNER)
	ctx.hooks.on(Ids.HOOK_SETTLE, _settle, Ids.PRIORITY_SETTLE, Ids.OWNER)


static func _day_start(ctx: CardCtx, _args: Dictionary) -> void:
	run_hook(ctx, str(Ids.HOOK_DAY_START))


static func _settle(ctx: CardCtx, _args: Dictionary) -> void:
	run_hook(ctx, str(Ids.HOOK_SETTLE))


## For every held relic in holding order: its passives, then its downsides, whose "hook" is this one.
## Source path relic:<id>/<passives|downsides>/<i>/<hook>. Stops as soon as the shelf goes dormant (an effect that
## gets the player arrested leaves the remaining relics idle, as the modifiers already are).
static func run_hook(ctx: CardCtx, hook: String) -> void:
	for d in Api.working_defs(ctx):
		if Api.dormant(ctx):
			return
		var id := str(d.get("id", ""))
		for field in Ids.PASSIVE_FIELDS:
			var rows = d.get(field, [])
			if typeof(rows) != TYPE_ARRAY:
				continue
			for i in range(rows.size()):
				var row = rows[i]
				if typeof(row) != TYPE_DICTIONARY or str(row.get("hook", "")) != hook:
					continue
				var effects = row.get("effects", [])
				if typeof(effects) == TYPE_ARRAY and not effects.is_empty():
					ctx.run(effects, "relic:%s/%s/%d/%s" % [id, field, i, hook])
