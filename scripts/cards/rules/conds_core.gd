# G03 条件按冻结 DSL 形状读取状态；隐藏本心只在引擎内部判断。
# 所有条件无副作用，组合条件按数组顺序求值。
class_name CardCondsCore
extends RefCounted
const H = preload("res://scripts/cards/rules/rules_helpers.gd")

static func test_op(ctx: CardCtx, value, op: StringName) -> bool:
	var r := H.peek(ctx)
	match op:
		&"all":
			for c in value:
				if not ctx.test(c): return false
			return true
		&"any":
			for c in value:
				if ctx.test(c): return true
			return false
		&"not": return not ctx.test(value)
		&"flag": return _truth(r.get("flags", {}).get(value, false))
		&"flag_eq": return r.get("flags", {}).get(value[0]) == value[1]
		&"counter_gte": return int(r.get("counters", {}).get(value[0], 0)) >= int(value[1])
		&"story": return str(r.get("story", {}).get(value[0], "")) == str(value[1])
		&"rep_tier_gte": return CardMeters.tier(ctx, &"rep") >= int(value)
		&"rep_tier_lte": return CardMeters.tier(ctx, &"rep") <= int(value)
		&"heat_tier_gte": return CardMeters.tier(ctx, &"heat") >= int(value)
		&"heat_tier_lte": return CardMeters.tier(ctx, &"heat") <= int(value)
		&"conscience_gte": return CardMeters.value(ctx, &"conscience") >= int(value)
		&"conscience_lte": return CardMeters.value(ctx, &"conscience") <= int(value)
		&"attr_gte": return CardMeters.attr(ctx, str(value[0]), StringName(value[1])) >= int(value[2])
		&"has_contact": return H.contact_uid(ctx, str(value)) != ""
		&"has_kept": return _has_kept(ctx, value)
		&"person_state": return str(H.person_peek(ctx, str(value[0])).get("state", "ok")) == str(value[1])
		&"dossier_has": return CardDossier.has_fragment(ctx, str(value))
		&"dossier_page_complete": return CardDossier.complete(ctx, str(value))
		&"demand_open":
			for uid in CardPiles.list(ctx, &"demands"):
				if str(value) == "*" or str(CardPiles.def_of(ctx, uid).get("kind", "")) == str(value): return true
	return false

static func _has_kept(ctx: CardCtx, match_def: Dictionary) -> bool:
	for uid in CardPiles.list(ctx, &"kept"):
		var d := CardPiles.def_of(ctx, uid)
		if match_def.has("def") and str(d.get("id", "")) != str(match_def["def"]): continue
		if match_def.has("tags_any") and not H.intersects(d.get("tags", []), match_def["tags_any"]): continue
		return true
	return false

static func _truth(value) -> bool:
	match typeof(value):
		TYPE_STRING: return str(value) != ""
		TYPE_INT: return int(value) != 0
		TYPE_BOOL: return value
	return false
