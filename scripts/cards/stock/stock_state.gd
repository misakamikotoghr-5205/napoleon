# Rogue v1 stocktake: read / write helpers for state.stock (ROGUE_V1.md §3.2). Owner RG2. No class_name; preload it.
# Lazy namespace: reads never create it (other modules' namespaces are only read through state.data.get); the
# first real write does. No rules file, enabled = false or nothing to offer = the module is off and writes nothing.
extends RefCounted

const Ids = preload("res://scripts/cards/stock/stock_ids.gd")
const RelicApi = preload("res://scripts/cards/relic/relic_api.gd")


## rules/stock.json present and enabled, and the data has something to offer (sources, or live relics).
static func active(ctx: CardCtx) -> bool:
	if ctx == null or ctx.db == null or ctx.state == null:
		return false
	var r := ctx.rules(Ids.RULES)
	if r.is_empty() or not bool(r.get("enabled", true)):
		return false
	return not ctx.db.ids_of(&"source").is_empty() or RelicApi.active(ctx)


## Cheap gate for the per-candidate modifier providers: the rules file is there and enabled.
static func enabled(ctx: CardCtx) -> bool:
	var r := ctx.rules(Ids.RULES)
	return not r.is_empty() and bool(r.get("enabled", true))


static func rule(ctx: CardCtx, key: String) -> Variant:
	return ctx.rules(Ids.RULES).get(key, Ids.DEFAULTS.get(key))


static func rule_int(ctx: CardCtx, key: String) -> int:
	return int(rule(ctx, key))


static func rule_list(ctx: CardCtx, key: String) -> Array:
	var v = rule(ctx, key)
	return v if typeof(v) == TYPE_ARRAY else Array(Ids.DEFAULTS.get(key, []))


static func clamp_value(ctx: CardCtx, key: String) -> int:
	var c = ctx.rules(Ids.RULES).get("clamp", {})
	return int(c.get(key, Ids.CLAMP[key])) if typeof(c) == TYPE_DICTIONARY else int(Ids.CLAMP[key])


## Read-only state.stock ({} when it was never written). The returned dictionary is the live one when present.
static func peek(ctx: CardCtx) -> Dictionary:
	var st = ctx.state.data.get(Ids.NS, {}) if ctx.state != null else {}
	return st if typeof(st) == TYPE_DICTIONARY else {}


## state.stock for writing; created (with its fixed shape) on first use.
static func ns(ctx: CardCtx) -> Dictionary:
	var st := ctx.state.ns(Ids.NS)
	if not st.has("_v"):
		st["_v"] = Ids.VERSION
	if typeof(st.get("deals")) != TYPE_DICTIONARY:
		st["deals"] = {}
	if typeof(st.get("offers")) != TYPE_DICTIONARY:
		st["offers"] = {}
	if typeof(st.get("sources")) != TYPE_ARRAY:
		st["sources"] = []
	return st


static func loop_of(ctx: CardCtx) -> Dictionary:
	var loop = ctx.state.data.get("loop", {})
	return loop if typeof(loop) == TYPE_DICTIONARY else {}


static func stage(ctx: CardCtx) -> int:
	return int(loop_of(ctx).get("stage", 0))


static func stage_day(ctx: CardCtx) -> int:
	return int(loop_of(ctx).get("stage_day", 0))


static func phase(ctx: CardCtx) -> String:
	return str(loop_of(ctx).get("phase", ""))


static func era(ctx: CardCtx) -> String:
	return str(ctx.db.stage(stage(ctx)).get("era", ""))


## Days 1-7 = week 0 … days 22-28 = week 3 (days 29-30 = week 4, never stocktaken).
static func week_of(day: int) -> int:
	return maxi(0, day - 1) / 7


static func deal_key(stage_index: int, week: int) -> String:
	return "%d:%d" % [stage_index, week]


static func deals(ctx: CardCtx, stage_index: int, week: int) -> int:
	var d = peek(ctx).get("deals", {})
	return int(d.get(deal_key(stage_index, week), 0)) if typeof(d) == TYPE_DICTIONARY else 0


## Deals made so far in the week that contains today.
static func week_deals(ctx: CardCtx) -> int:
	return deals(ctx, stage(ctx), week_of(stage_day(ctx)))


static func offers(ctx: CardCtx) -> Dictionary:
	var o = peek(ctx).get("offers", {})
	return o if typeof(o) == TYPE_DICTIONARY else {}


static func offer(ctx: CardCtx, id: String) -> Dictionary:
	var o = offers(ctx).get(id, {})
	return o if typeof(o) == TYPE_DICTIONARY else {}


## The most recent open offer: largest abs_day, ties broken by id (sorted keys; save files sort keys anyway).
static func latest_open(ctx: CardCtx) -> String:
	var all := offers(ctx)
	var ids: Array = all.keys()
	ids.sort()
	var best := ""
	var best_day := -1
	for id in ids:
		var o = all[id]
		if typeof(o) != TYPE_DICTIONARY or str(o.get("status", "")) != Ids.ST_OPEN:
			continue
		if int(o.get("abs_day", 0)) >= best_day:
			best = str(id)
			best_day = int(o.get("abs_day", 0))
	return best


## Rows of state.stock.sources that belong to the current stage, in pick order.
static func live_sources(ctx: CardCtx) -> Array:
	var rows = peek(ctx).get("sources", [])
	var out: Array = []
	if typeof(rows) != TYPE_ARRAY:
		return out
	var now := stage(ctx)
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY and int(row.get("stage", -1)) == now:
			out.append(row)
	return out


static func live_source_ids(ctx: CardCtx) -> PackedStringArray:
	var out := PackedStringArray()
	for row in live_sources(ctx):
		out.append(str(row.get("id", "")))
	return out


## ladder.prison.uid is set while the player is jailed (G06); read without creating the namespace.
static func in_prison(ctx: CardCtx) -> bool:
	var ladder = ctx.state.data.get("ladder", {})
	if typeof(ladder) != TYPE_DICTIONARY or typeof(ladder.get("prison")) != TYPE_DICTIONARY:
		return false
	return str(ladder["prison"].get("uid", "")) != ""


static func def_of(ctx: CardCtx, id: String) -> Dictionary:
	return ctx.db._cards.get(id, {}) if ctx.db != null else {}


static func changed(ctx: CardCtx, topics: Array = ["stock"]) -> void:
	ctx.emit(&"view_changed", [PackedStringArray(topics)])
