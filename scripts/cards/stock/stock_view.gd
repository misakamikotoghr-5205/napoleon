# Rogue v1: what the table reads about the stocktake — view block "stock" and the query "stocktake"
# (ROGUE_V1.md §4.3, §4.8). Only ids, art, depth words, counts the player made (deals) and statuses; never weights,
# percentages or any effect size. Owner RG2. No class_name; preload it.
extends RefCounted

const Ids = preload("res://scripts/cards/stock/stock_ids.gd")
const S = preload("res://scripts/cards/stock/stock_state.gd")
const RelicApi = preload("res://scripts/cards/relic/relic_api.gd")


## view_section provider: {"stock": {open, week_deals, sources: [{id, art}]}} while the module is on.
static func section(ctx: CardCtx, _args: Dictionary) -> Dictionary:
	if not S.active(ctx):
		return {}
	var sources: Array = []
	for row in S.live_sources(ctx):
		var id := str(row.get("id", ""))
		sources.append({"id": id, "art": str(S.def_of(ctx, id).get("art", ""))})
	return {"stock": {"open": S.latest_open(ctx), "week_deals": S.week_deals(ctx), "sources": sources}}


## stocktake {offer?}: one offer with its items and the shelf (held / cap / full) for the "give one up" step.
## No offer id = the latest open one (none -> not_allowed); an unknown or mistyped id -> bad_args. Read only: other
## keys (a panel's open() args) are ignored.
static func query(ctx: CardCtx, args: Dictionary) -> Dictionary:
	var given = args.get("offer", "")
	if typeof(given) != TYPE_STRING and typeof(given) != TYPE_STRING_NAME:
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	var id := str(given)
	if id == "":
		id = S.latest_open(ctx) if S.active(ctx) else ""
		if id == "":
			return {"ok": false, "err": CardIds.ERR_NOT_ALLOWED}
	var rec := S.offer(ctx, id)
	if rec.is_empty():
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	var items: Array = []
	for row in rec.get("items", []):
		if typeof(row) == TYPE_DICTIONARY:
			items.append(item_row(ctx, str(row.get("id", "")), str(row.get("kind", ""))))
	return {"ok": true, "err": "", "offer": id, "from": str(rec.get("from", "")), "stage": int(rec.get("stage", 0)),
		"week": int(rec.get("week", -1)), "deals": int(rec.get("deals", 0)), "status": str(rec.get("status", "")),
		"picked": str(rec.get("picked", "")), "items": items, "cap": RelicApi.cap(ctx), "full": RelicApi.is_full(ctx),
		"held": held_rows(ctx)}


static func item_row(ctx: CardCtx, id: String, kind: String) -> Dictionary:
	var d := S.def_of(ctx, id)
	var depth := str(d.get("depth", "")) if kind == Ids.KIND_RELIC else ""
	return {"id": id, "kind": kind, "art": str(d.get("art", "")), "depth": depth}


static func held_rows(ctx: CardCtx) -> Array:
	var out: Array = []
	for id in RelicApi.held_ids(ctx):
		var d := S.def_of(ctx, id)
		out.append({"id": id, "art": str(d.get("art", "")), "depth": str(d.get("depth", ""))})
	return out
