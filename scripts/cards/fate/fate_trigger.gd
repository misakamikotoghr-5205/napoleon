# 命运频率纯查询；只有实际发牌后记录时间。
# 危机只发 bf.wheel，一关次数与每类危机各自限额。
class_name CardFateTrigger
extends RefCounted
const S = preload("res://scripts/cards/fate/fate_support.gd")

static func fate_due(ctx: CardCtx) -> bool:
	var spec: Dictionary = ctx.rules("fate").get("fate", {})
	var gap := ctx.abs_day() - int(ctx.state.ns("fate").get("fate_last_abs_day", 0))
	if gap < int(spec.get("min_gap", 3)):
		return false
	if gap >= int(spec.get("max_gap", 4)):
		return true
	var bonuses: Array = spec.get("heat_tier_bonus", [0, 0, 1, 1, 2])
	var num := int(spec.get("num", 1)) + int(bonuses[mini(S.tier(ctx, &"heat"), bonuses.size() - 1)])
	return ctx.draw("c.fate.due", [ctx.abs_day()]) * float(maxi(1, int(spec.get("den", 2)))) < float(num)

static func crisis(ctx: CardCtx) -> StringName:
	var ladder := ctx.state.ns("ladder")
	var thresholds: Dictionary = ctx.rules("fate").get("big", {}).get("crisis", {})
	if not (ladder.get("prison", {}) as Dictionary).is_empty():
		return &"arrested"
	if S.meter(ctx, &"heat") >= int(ctx.rules("meters").get("heat", {}).get("arrest_at", 100)):
		return &"heat_max"
	var street: Dictionary = ladder.get("street", {})
	if not street.is_empty() and ctx.abs_day() - int(street.get("since_abs_day", ctx.abs_day())) >= int(thresholds.get("street_long", {}).get("days_gte", 3)):
		return &"street_long"
	if not (ladder.get("short", {}) as Dictionary).is_empty() and _held(ctx) <= int(thresholds.get("cash_short", {}).get("estates_left_lte", 1)):
		return &"cash_short"
	return &""

static func _held(ctx: CardCtx) -> int:
	var count := 0
	for row in ctx.state.ns("ladder").get("estates", {}).values():
		if str(row.get("status", "held")) == "held":
			count += 1
	return count

static func on_crisis(ctx: CardCtx, kind: StringName) -> void:
	if not str(kind) in ["cash_short", "arrested", "heat_max", "street_long"]:
		return
	var fate := ctx.state.ns("fate")
	var big: Dictionary = fate.get("big", {"stage_count": 0, "crises_used": []})
	var config: Dictionary = ctx.rules("fate").get("big", {})
	if int(big.get("stage_count", 0)) >= int(config.get("max_per_stage", 2)):
		return
	var used: Array = big.get("crises_used", [])
	if bool(config.get("once_per_crisis", true)) and used.has(str(kind)):
		return
	if kind == &"cash_short" and _held(ctx) > int(config.get("crisis", {}).get("cash_short", {}).get("estates_left_lte", 1)):
		return
	if not ctx.db.has("bf.wheel"):
		return
	var uid := CardPiles.spawn(ctx, "bf.wheel", CardIds.ZONE_HAND)
	big["stage_count"] = int(big.get("stage_count", 0)) + 1
	used.append(str(kind))
	big["crises_used"] = used
	fate["big"] = big
	CardFirsts.mark(ctx, &"big_wheel", {"uid": uid})
