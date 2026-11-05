# 报告只含正文键与整数参数；收集结算钩子的告示以及钱和档位变化。
# G02 的私有辅助，不注册全局类，不读隐藏数字到视图。
extends RefCounted

static func snapshot(ctx: CardCtx) -> Dictionary:
	return {"money": CardCurrency.money(ctx), "rep_tier": CardMeters.tier(ctx, &"rep"),
		"heat_tier": CardMeters.tier(ctx, &"heat")}

static func notices(ctx: CardCtx, start: int = 0) -> Array:
	var rows: Array = []
	for ev in ctx.out.slice(start):
		if ev.size() >= 3 and StringName(ev[0]) == &"notice":
			rows.append({"key": str(ev[1]), "args": integer_args(ev[2])})
	return rows

static func integer_args(v: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(v) == TYPE_DICTIONARY:
		var keys: Array = v.keys()
		keys.sort()
		for k in keys:
			if typeof(v[k]) == TYPE_INT:
				out[str(k)] = int(v[k])
	return out

static func finish_settle(ctx: CardCtx, start: int) -> void:
	var loop := ctx.state.ns("loop")
	var rows: Array = loop.get("end_lines", []).duplicate(true)
	rows.append_array(notices(ctx, start))
	var before: Dictionary = loop.get("morning_snapshot", snapshot(ctx))
	var after := snapshot(ctx)
	var delta := int(after["money"]) - int(before.get("money", after["money"]))
	rows.append({"key": "g02.settle.money_in" if delta >= 0 else "g02.settle.money_out", "args": {"money": absi(delta)}})
	for meter in ["rep_tier", "heat_tier"]:
		if int(before.get(meter, after[meter])) != int(after[meter]):
			rows.append({"key": "g02.settle." + meter, "args": {"from": int(before[meter]), "to": int(after[meter])}})
	for _uid in loop.get("gold_left", []):
		rows.append({"key": "g02.settle.gold_left", "args": {"n": 1}})
	loop["reports"]["settle"] = {"lines": rows}

static func finish_month(ctx: CardCtx, start: int) -> void:
	var rows := notices(ctx, start)
	for row in ctx.state.ns("loop").get("goals", []):
		rows.append({"key": "g02.month.goal." + str(row.get("status", "open")), "args": {"n": 1}})
	rows.append({"key": CardGoals.verdict_key(ctx), "args": {}})
	ctx.state.ns("loop")["reports"]["month"] = {"lines": rows}


static func extend_month(ctx: CardCtx, start: int) -> void:
	var loop := ctx.state.ns("loop")
	var old: Array = loop.get("reports", {}).get("month", {}).get("lines", [])
	var notices_only: Array = []
	for row in old:
		if not str(row.get("key", "")).begins_with("g02.month."):
			notices_only.append(row)
	finish_month(ctx, start)
	var current: Array = loop["reports"]["month"]["lines"]
	loop["reports"]["month"]["lines"] = notices_only + current
