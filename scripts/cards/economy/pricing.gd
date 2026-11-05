# 三档报价只用开口价及可见成色档估计；鉴定的清晰度不改报价，说破（主创 10-25）只通过客人改过的开价影响这里。
# G04；百分比仅留在规则和修正项内。
class_name CardPricing
extends RefCounted
const E = preload("res://scripts/cards/economy/economy_support.gd")

static func tiers(ctx: CardCtx, uid: String) -> Dictionary:
	var s := E.session(ctx, uid)
	var direction := "receive" if str(s.get("intent", "")) == "buy" else "pay"
	var item := str(s.get("item", ""))
	var base: int = E.visible_amount(ctx, item) if direction == "receive" else int(s.get("asking", 0))
	if s.is_empty() or item == "":
		return {"harsh": 0, "fair": 0, "kind": 0, "direction": direction}
	var pct: int = ctx.mods.pct(ctx, &"price_pct", {"direction": direction, "cat": str(E.meta(ctx, item).get("cat", "")), "item_id": item})
	var tier_rules: Dictionary = ctx.rules("economy").get("tiers", {}).get(direction, {})
	return {"harsh": maxi(1, base * int(tier_rules.get("harsh", 100)) * pct / 10000),
		"fair": maxi(1, base * int(tier_rules.get("fair", 100)) * pct / 10000),
		"kind": maxi(1, base * int(tier_rules.get("kind", 100)) * pct / 10000), "direction": direction}
