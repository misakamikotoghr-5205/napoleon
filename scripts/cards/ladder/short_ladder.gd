# 付不起时按货物、家当、认了给出可用路线；保存面板参数以便读档恢复。
# G06；合同 §7.4.5。认了只执行原来源 on_short，街头只能由月底铺面丢失进入。
class_name CardShortLadder
extends RefCounted


static func on_short(ctx: CardCtx, args: Dictionary) -> void:
	var total: int = int(args.get("amount", 0))
	var pending: Dictionary = ctx.state.ns("econ").get("pending_payment", {})
	ctx.state.ns("ladder")["short_payment"] = {"amount": total,
		"reason": str(pending.get("reason", "g06.short.payment"))}
	var panel: Dictionary = {"amount": maxi(0, total - CardCurrency.money(ctx)),
		"payee": str(args.get("payee", "")), "source": str(args.get("source", "")),
		"options": [], "goods": CardShelf.view(ctx), "estates": []}
	for estate in CardMortgage.view(ctx):
		if str(estate.get("status", "")) == "held":
			(panel["estates"] as Array).append(estate)
	for option in ctx.rules("ladder").get("short", {}).get("order", ["goods", "estate", "street"]):
		if str(option) == "goods" and not (panel["goods"] as Array).is_empty():
			(panel["options"] as Array).append("goods")
		elif str(option) == "estate" and not (panel["estates"] as Array).is_empty():
			(panel["options"] as Array).append("estate")
	(panel["options"] as Array).append("default")
	ctx.state.ns("ladder")["short"] = panel
	CardFirsts.mark(ctx, &"money_short", {})
	if (panel["options"] as Array).has("estate"):
		CardFirsts.mark(ctx, &"mortgage", {})
	CardDayLoop.request_panel(ctx, &"short", panel)


static func view(ctx: CardCtx) -> Dictionary:
	return (ctx.state.ns("ladder").get("short", {}) as Dictionary).duplicate(true)


static func resolve(ctx: CardCtx, args: Dictionary) -> Dictionary:
	var panel: Dictionary = view(ctx)
	if panel.is_empty() or str(args.get("source", "")) != str(panel.get("source", "")):
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	var by: String = str(args.get("by", ""))
	if not (panel.get("options", []) as Array).has(by):
		return {"ok": false, "err": CardIds.ERR_NOT_ALLOWED}
	if by == "goods":
		var item: String = str(args.get("item", ""))
		var found: bool = false
		for good in panel["goods"]:
			if str(good.get("item", "")) == item:
				found = true
		if not found or not CardShelf.items(ctx).has(item):
			return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
		# TODO(design): 按可见模板基价和成色给保守抵价，余额保留并继续选路线。
		var support: Script = load("res://scripts/cards/economy/economy_support.gd")
		var amount: int = int(support.call("visible_amount", ctx, item))
		CardShelf.remove(ctx, item, "g06.short.goods")
		ctx.run([{"op": "money", "delta": amount, "reason": "g06.short.goods"}], str(panel["source"]))
	elif by == "estate":
		var result: Dictionary = CardMortgage.mortgage(ctx, str(args.get("estate", "")))
		if not bool(result.get("ok", false)):
			return result
	return _pay_or_continue(ctx, panel, by == "default")


static func _pay_or_continue(ctx: CardCtx, panel: Dictionary, defaulted: bool) -> Dictionary:
	var ladder: Dictionary = ctx.state.ns("ladder")
	var payment: Dictionary = ladder.get("short_payment", {})
	var total: int = int(payment.get("amount", panel.get("amount", 0)))
	if not defaulted and not ctx.test({"money_gte": total}):
		on_short(ctx, {"amount": total, "payee": panel["payee"], "source": panel["source"]})
		return {"ok": true, "err": "", "pending": true}
	var economy: Script = null
	if defaulted and ctx.ops.owner_of(&"pay") == "G04":
		economy = load("res://scripts/cards/economy/economy_install.gd")
		if not economy.has_method("fail_payment"):
			return {"ok": false, "err": CardIds.ERR_NOT_IMPLEMENTED}
	ladder["short"] = {}
	ladder.erase("short_payment")
	if economy != null:
		# 显式认了不依赖当前余额；G04 同时保护 on_short 递归与新待付款。
		economy.call("fail_payment", ctx, str(panel["source"]))
	else:
		# W1 替身通过登记的 pay handler 验证 fail 语义；真实付款走同一个 op。
		ctx.run([{"op": "pay", "amount": total, "payee": panel["payee"],
			"reason": str(payment.get("reason", "g06.short.payment")), "short": "fail"}], str(panel["source"]))
	# 别的后果可能又打开新面板，只关闭仍属于本次 short 的面板。
	var current: Dictionary = ctx.state.ns("loop").get("open_panel", {})
	if str(current.get("kind", "")) == "short" and view(ctx).is_empty():
		CardDayLoop.request_panel(ctx, &"", {})
	return {"ok": true, "err": "", "defaulted": defaulted}


static func _day_end(ctx: CardCtx, _args: Dictionary) -> void:
	# 合同 1.2：打烊 priority 7 将没选的钱不够按认了结算。
	var panel: Dictionary = view(ctx)
	if not panel.is_empty():
		resolve(ctx, {"source": panel.get("source", ""), "by": "default"})
