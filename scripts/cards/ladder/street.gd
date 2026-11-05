# 铺面月底丢失才进入街头；攒够押值可赎回铺面。
# G06；合同 §7.4.6、§7.9。模式与面板只经 CardDayLoop 改。
class_name CardStreet
extends RefCounted

const SHOP := "es.shopfront"


static func enter(ctx: CardCtx) -> void:
	var street: Dictionary = ctx.state.ns("ladder").get("street", {})
	if str(ctx.state.ns("loop").get("mode", "shop")) != "street":
		street["since_abs_day"] = ctx.abs_day()
	ctx.state.ns("ladder")["street"] = street
	CardDayLoop.set_mode(ctx, &"street")
	CardFirsts.mark(ctx, &"street", {})


static func redeem_shop(ctx: CardCtx) -> Dictionary:
	if str(ctx.state.ns("loop").get("mode", "")) != "street":
		return {"ok": false, "err": CardIds.ERR_NOT_ALLOWED}
	var amount: int = shop_price(ctx)
	if not ctx.test({"money_gte": amount}):
		return {"ok": false, "err": CardIds.ERR_INSUFFICIENT_MONEY}
	ctx.run([{"op": "pay", "amount": amount, "payee": SHOP,
		"reason": "g06.reason.redeem_shop", "short": "fail"}], SHOP)
	var entry: Dictionary = CardMortgage._entry(ctx, SHOP)
	entry.merge({"status": "held", "since_abs_day": ctx.abs_day(), "principal": 0}, true)
	entry.erase("interest_paid_stage")
	ctx.state.ns("ladder")["street"]["since_abs_day"] = 0
	CardDayLoop.set_mode(ctx, &"shop")
	ctx.emit(&"notice", ["g06.street.redeemed", {"money": amount}])
	return {"ok": true, "err": "", "money": amount}


static func shop_price(ctx: CardCtx) -> int:
	return int(ctx.db.def(SHOP).get("mortgage_value", 0)) \
		* int(ctx.rules("ladder").get("street", {}).get("redeem_shop_pct", 100)) / 100 \
		* int(ctx.state.ns("econ").get("price_index", 100)) / 100
