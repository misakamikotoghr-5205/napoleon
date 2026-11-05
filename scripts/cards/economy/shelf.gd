# 货架只保存账本中位于 stock 的物品；界面仅得到可见字段。
# G04；上限由经济规则和抵押修正提供。
class_name CardShelf
extends RefCounted
const E = preload("res://scripts/cards/economy/economy_support.gd")

static func items(ctx: CardCtx) -> PackedStringArray:
	E.ensure(ctx, false)
	var out := PackedStringArray(ctx.ledger.items_at("stock"))
	out.sort()
	return out

static func cap(ctx: CardCtx) -> int:
	return maxi(0, int(ctx.rules("economy").get("shelf_cap", 12)) + ctx.mods.sum_int(ctx, &"cap", {"zone": &"shelf"}))

static func add(ctx: CardCtx, item: Dictionary, source: String) -> String:
	E.ensure(ctx)
	if items(ctx).size() >= cap(ctx):
		return ""
	var id := str(item.get("item", item.get("id", "")))
	if not ctx.ledger.items.has(id):
		return ""
	ctx.ledger.move_item(id, "stock", "player", source)
	E.meta(ctx, id)["on_shelf_since"] = ctx.abs_day()
	E.sync(ctx)
	CardFirsts.mark(ctx, &"shelf", {})
	return id

static func remove(ctx: CardCtx, item_id: String, reason: String) -> void:
	E.ensure(ctx)
	if not items(ctx).has(item_id):
		return
	ctx.ledger.move_item(item_id, "removed", "", reason)
	E.sync(ctx)

static func view(ctx: CardCtx) -> Array:
	var out: Array = []
	for id in items(ctx):
		out.append(E.item_view(ctx, id))
	return out
