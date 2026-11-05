# Rogue v1: the customer sources' standing modifiers (ROGUE_V1.md §4.5, §5.5): pool_pct and deal_count.
# Only sources picked in the current stage count. Rows: {mod: pool_weight, pool, tags_any?, intents?, pct, when?} and
# {mod: deal_count, type, delta, when?}; the product (pool_pct) or sum (deal_count) is clamped by rules/stock.json.
# These run for every deal candidate: without a live source the first lines return the neutral value.
# Owner RG2. No class_name; preload it.
extends RefCounted

const Ids = preload("res://scripts/cards/stock/stock_ids.gd")
const S = preload("res://scripts/cards/stock/stock_state.gd")


## args {pool, def} (fate/weights.gd). 100 = unchanged.
static func pool_pct(ctx: CardCtx, args: Dictionary) -> int:
	var rows := _rows(ctx)
	if rows.is_empty():
		return 100
	var pool := str(args.get("pool", ""))
	var d: Dictionary = S.def_of(ctx, str(args.get("def", "")))
	var total := 100
	var hit := false
	for src in rows:
		for m in S.def_of(ctx, str(src.get("id", ""))).get("mods", []):
			if typeof(m) != TYPE_DICTIONARY or str(m.get("mod", "")) != Ids.MOD_POOL or str(m.get("pool", "")) != pool:
				continue
			if not _card_matches(m, d) or (m.has("when") and not ctx.test(m["when"])):
				continue
			total = total * int(m.get("pct", 100)) / 100
			hit = true
	if not hit:
		return 100
	return clampi(total, S.clamp_value(ctx, "pool_min"), S.clamp_value(ctx, "pool_max"))


## args {type: pool, abs_day} (core/card_composer.gd). 0 = unchanged.
static func deal_count(ctx: CardCtx, args: Dictionary) -> int:
	var rows := _rows(ctx)
	if rows.is_empty():
		return 0
	var type := str(args.get("type", ""))
	var total := 0
	var hit := false
	for src in rows:
		for m in S.def_of(ctx, str(src.get("id", ""))).get("mods", []):
			if typeof(m) != TYPE_DICTIONARY or str(m.get("mod", "")) != Ids.MOD_DEALS or str(m.get("type", "")) != type:
				continue
			if m.has("when") and not ctx.test(m["when"]):
				continue
			total += int(m.get("delta", 0))
			hit = true
	if not hit:
		return 0
	return clampi(total, S.clamp_value(ctx, "deal_count_min"), S.clamp_value(ctx, "deal_count_max"))


## Live source rows of the current stage; [] (cheaply) when none was ever picked or the module is off.
static func _rows(ctx: CardCtx) -> Array:
	var st = ctx.state.data.get(Ids.NS) if ctx.state != null else null
	if typeof(st) != TYPE_DICTIONARY:
		return []
	var rows = st.get("sources", [])
	if typeof(rows) != TYPE_ARRAY or (rows as Array).is_empty() or not S.enabled(ctx):
		return []
	return S.live_sources(ctx)


## tags_any: missing / empty = every card, otherwise it must share a tag; intents: missing / empty = every card,
## otherwise it must contain the card's intent.
static func _card_matches(m: Dictionary, d: Dictionary) -> bool:
	var tags_any = m.get("tags_any", [])
	if typeof(tags_any) == TYPE_ARRAY and not (tags_any as Array).is_empty():
		var tags = d.get("tags", [])
		var shared := false
		for tag in tags_any:
			if typeof(tags) == TYPE_ARRAY and (tags as Array).has(tag):
				shared = true
				break
		if not shared:
			return false
	var intents = m.get("intents", [])
	if typeof(intents) == TYPE_ARRAY and not (intents as Array).is_empty():
		return (intents as Array).has(str(d.get("intent", "")))
	return true
