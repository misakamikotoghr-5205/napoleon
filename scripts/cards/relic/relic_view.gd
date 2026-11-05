# Rogue v1 relics: the visible "relics" view block (view_section) and the read-only "relics" query.
# Owner RG1 (docs/cards/rogue/ROGUE_V1.md §4.3, §4.8). No class_name. Only ids, art, depth words, the dormant flag,
# the cell count and the day a relic was taken: never a modifier size (red line: hidden values stay hidden).
extends RefCounted

const Ids = preload("res://scripts/cards/relic/relic_ids.gd")
const Api = preload("res://scripts/cards/relic/relic_api.gd")


## view_section provider: {"relics": block} while the module is on (the example set and relic-less data have none).
static func section(ctx: CardCtx, _args: Dictionary) -> Dictionary:
	if ctx.state == null or not Api.active(ctx):
		return {}
	return {Ids.VIEW_KEY: block(ctx)}


## {"cap", "count", "dormant", "held": [{"id", "art", "depth", "since"}]} in holding order.
static func block(ctx: CardCtx) -> Dictionary:
	var held: Array = []
	for row in Api._peek(ctx).get("held", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var id := str(row.get("id", ""))
		var d: Dictionary = ctx.db._cards.get(id, {})
		if str(d.get("type", "")) != "relic":
			continue
		held.append({"id": id, "art": str(d.get("art", "")), "depth": str(d.get("depth", "")),
			"since": int(row.get("since", 0))})
	return {"cap": Api.cap(ctx), "count": held.size(), "dormant": Api.dormant(ctx), "held": held}


## Query "relics" {}: the same block with ok/err; an empty shelf when the module is off. Read only.
static func query(ctx: CardCtx, _args: Dictionary) -> Dictionary:
	var out := {"ok": true, "err": "", "cap": Api.cap(ctx), "count": 0, "dormant": false, "held": []}
	if Api.active(ctx):
		out.merge(block(ctx), true)
	return out
