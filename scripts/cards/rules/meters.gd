# 五档名声和隐藏本心；属性的临时修正独立记账，到期删除。
# G03 只写 rules，跨关保留，风声到顶经 arrest 效果执行。
class_name CardMeters
extends RefCounted
const H = preload("res://scripts/cards/rules/rules_helpers.gd")

static func value(ctx: CardCtx, meter: StringName) -> int:
	return int(H.peek(ctx).get("meters", {}).get(str(meter), ctx.rules("meters").get(str(meter), {}).get("start", 0)))

static func tier(ctx: CardCtx, meter: StringName) -> int:
	var thresholds: Array = ctx.rules("meters").get(str(meter), {}).get("tiers", [0])
	var result := 0
	for i in range(thresholds.size()):
		if value(ctx, meter) >= int(thresholds[i]):
			result = i
	return result

static func add(ctx: CardCtx, meter: StringName, delta: int, source: String) -> void:
	var cfg: Dictionary = ctx.rules("meters").get(str(meter), {})
	var old := tier(ctx, meter)
	(H.state(ctx)["meters"] as Dictionary)[str(meter)] = clampi(value(ctx, meter) + delta, int(cfg.get("min", 0)), int(cfg.get("max", 100)))
	var now := tier(ctx, meter)
	if meter in [&"rep", &"heat"] and old != now:
		ctx.emit(&"tier_changed", [meter, old, now])
		CardFirsts.mark(ctx, StringName("tier_" + str(meter)), {"kind": str(meter)})
	if meter == &"heat" and value(ctx, meter) >= int(cfg.get("arrest_at", 100)):
		ctx.run([{"op": "arrest", "reason": "g03.arrest.heat"}], source + "/arrest")

static func bump_tier(ctx: CardCtx, meter: StringName, steps: int, source: String) -> void:
	var thresholds: Array = ctx.rules("meters").get(str(meter), {}).get("tiers", [0])
	var current := tier(ctx, meter)
	var target := clampi(current + steps, 0, thresholds.size() - 1)
	if current != target:
		add(ctx, meter, int(thresholds[target]) - value(ctx, meter), source)

static func attr(ctx: CardCtx, who: String, attr: StringName) -> int:
	var base: Dictionary = ctx.db.def("self.ruhua" if who == "ruhua" else "ct." + who).get("attrs", {})
	if base.is_empty():
		base = ctx.db.persons().get(who, {}).get("attrs", {})
	var n := int(H.peek(ctx).get("attrs", {}).get(who, {}).get(str(attr), base.get(str(attr), 0)))
	for mod in H.peek(ctx).get("attr_mods", []):
		if str(mod.get("who", "")) == who and str(mod.get("attr", "")) == str(attr) and int(mod.get("until_abs_day", 0)) > ctx.abs_day():
			n += int(mod.get("delta", 0))
	var cfg: Dictionary = ctx.rules("meters").get("attr", {})
	return clampi(n, int(cfg.get("min", 0)), int(cfg.get("max", 6)))

static func add_attr(ctx: CardCtx, who: String, attr: StringName, delta: int, days: int, source: String) -> void:
	var r := H.state(ctx)
	if days > 0:
		(r["attr_mods"] as Array).append({"who": who, "attr": str(attr), "delta": delta, "until_abs_day": ctx.abs_day() + days, "source": source})
	else:
		var attrs: Dictionary = r["attrs"]
		if not attrs.has(who):
			attrs[who] = ctx.db.def("self.ruhua" if who == "ruhua" else "ct." + who).get("attrs", {}).duplicate(true)
		var cfg: Dictionary = ctx.rules("meters").get("attr", {})
		attrs[who][str(attr)] = clampi(int(attrs[who].get(str(attr), 0)) + delta, int(cfg.get("min", 0)), int(cfg.get("max", 6)))

static func initialize(ctx: CardCtx) -> void:
	var r := H.state(ctx)
	for meter in ["rep", "heat", "conscience"]:
		if not (r["meters"] as Dictionary).has(meter):
			r["meters"][meter] = int(ctx.rules("meters").get(meter, {}).get("start", 0))
	if not (r["attrs"] as Dictionary).has("ruhua"):
		r["attrs"]["ruhua"] = ctx.db.def("self.ruhua").get("attrs", {}).duplicate(true)

static func expire_mods(ctx: CardCtx) -> void:
	var keep: Array = []
	for mod in H.state(ctx)["attr_mods"]:
		if int(mod.get("until_abs_day", 0)) > ctx.abs_day():
			keep.append(mod)
	H.state(ctx)["attr_mods"] = keep
