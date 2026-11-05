# 金色角色牌：手牌排序的子键 hand_sub、打烊时的金色牌流程（打烊确认的清单里有它那一行 kind gold_leave → 确认后走掉，§7.4.7）。
# 主人 G02；W0 写了 hand_sub 与 pending，leave 留给 G02。合同：docs/cards/CARDS_INTERFACES.md §10。
class_name CardGoldRule
extends RefCounted


## hand_sub 修正项的提供者：金色牌返回 schedule.order，其余 0（不自己挪牌）
static func hand_sub(ctx: CardCtx, uid: String) -> int:
	var d := CardPiles.def_of(ctx, uid)
	if not bool(d.get("gold", false)):
		return 0
	var sch = d.get("schedule", {})
	return int(sch.get("order", 0)) if typeof(sch) == TYPE_DICTIONARY else 0


## 手上还没处理的金色牌
static func pending(ctx: CardCtx) -> PackedStringArray:
	var out := PackedStringArray()
	for uid in CardPiles.list(ctx, CardIds.ZONE_HAND):
		if bool(CardPiles.def_of(ctx, uid).get("gold", false)):
			out.append(uid)
	return out


static func leave(ctx: CardCtx, uid: String) -> void:
	if not pending(ctx).has(uid):
		return
	ctx.emit(&"card_left", [uid, &"gold_left"])
	ctx.run(CardPiles.def_of(ctx, uid).get("effects", {}).get("on_expire", []), uid + "/gold_left")
	CardPiles.move(ctx, uid, CardIds.ZONE_DISCARD)
	(ctx.state.ns("loop")["gold_left"] as Array).append(uid)
