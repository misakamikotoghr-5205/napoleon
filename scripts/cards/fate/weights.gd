# 牌库权重逐项使用整数百分比，零权重与不满足条件的牌不上表。
# 系数由 weights.json 提供；运势、临时修正、家当修正按合同顺序叠加。
class_name CardWeights
extends RefCounted
const S = preload("res://scripts/cards/fate/fate_support.gd")

static func rows(ctx: CardCtx, pool: StringName) -> Array:
	var out: Array = []
	var factors := _active_factors(ctx)
	for entry in _entries(ctx, pool):
		var def := {"id": str(entry[0]), "weight": int(entry[1]), "conditions": entry[2], "tags": entry[3], "valence": str(entry[4]) if entry.size() > 4 else str(ctx.db.def(str(entry[0])).get("valence", ""))}
		if str(pool) == "big_fate" or not ctx.test(def["conditions"]) or S.intersects(Array(CardPins.banned(ctx, ctx.abs_day())), def["tags"]):
			continue
		var weight := int(def["weight"])
		for pct in _percentages(ctx, str(pool), def, factors):
			weight = weight * int(pct) / 100
		if weight > 0:
			out.append([str(def["id"]), weight])
	return out

static func _entries(ctx: CardCtx, pool: StringName) -> Array:
	if ctx.db.has_method("deal_rows"):
		return ctx.db.call("deal_rows", pool, S.era(ctx))
	var rows: Array = []
	for id in ctx.db.pool(pool, S.era(ctx)):
		var def := ctx.db.def(id)
		rows.append([id, int(def.get("weight", 10)), def.get("conditions", {}), def.get("tags", []), str(def.get("valence", ""))])
	return rows

static func _active_factors(ctx: CardCtx) -> Array:
	var selected: Array = []
	var fields := {"era": S.era(ctx), "rep_tier": S.tier(ctx, &"rep"), "heat_tier": S.tier(ctx, &"heat"),
		"weather": str(ctx.state.ns("fate").get("weather", "clear")),
		"market_day": CardCalendar.is_market_day(ctx, int(ctx.state.ns("loop").get("stage_day", 0)))}
	for row in ctx.rules("weights").get("factors", []):
		var active := true
		for field in ["era", "rep_tier", "heat_tier", "weather", "market_day"]:
			if not row.has(field):
				continue
			if field == "market_day":
				active = active and bool(row[field]) == bool(fields[field])
			else:
				active = active and row[field].has(fields[field])
		if active:
			selected.append(row)
	return selected

static func matches(row: Dictionary, pool: String, def: Dictionary) -> bool:
	if row.has("pool") and str(row["pool"]) != pool:
		return false
	if row.has("def") and str(row["def"]) != str(def.get("id", "")):
		return false
	if row.has("valence") and str(row["valence"]) != str(def.get("valence", "")):
		return false
	return not row.has("tags_any") or S.intersects(row["tags_any"], def.get("tags", []))

static func _percentages(ctx: CardCtx, pool: String, def: Dictionary, factors: Array) -> Array:
	var out: Array = []
	for row in factors:
		if matches(row, pool, def):
			out.append(int(row.get("pct", 100)))
	for row in ctx.state.ns("fate").get("month_mods", []):
		if matches(row, pool, def):
			out.append(int(row.get("pct", 100)))
	for row in ctx.state.ns("fate").get("deck_mods", []):
		if int(row.get("until_abs_day", -1)) >= ctx.abs_day() and matches(row, pool, def):
			out.append(int(row.get("pct", 100)))
	out.append(ctx.mods.pct(ctx, &"pool_pct", {"pool": pool, "def": str(def.get("id", ""))}))
	return out

static func deal_count(ctx: CardCtx, args: Dictionary) -> int:
	if str(args.get("type", "")) != "person":
		return 0
	var stage_day := int(ctx.state.ns("loop").get("stage_day", 0)) + int(args.get("abs_day", ctx.abs_day())) - ctx.abs_day()
	var spec: Dictionary = ctx.rules("deal").get("person", {})
	var result := int(spec.get("market_bonus", 0)) if CardCalendar.is_market_day(ctx, stage_day) else 0
	if str(ctx.state.ns("fate").get("weather", "clear")) == "rain":
		result -= int(spec.get("rain_penalty", 0))
	return result
