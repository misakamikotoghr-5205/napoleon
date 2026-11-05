# 月账开销和清点通过 notice 交给日循环汇总；同阶段重复触发幂等。
# G04；抵押利息由 G06 处理。
class_name CardMonthAccounts
extends RefCounted
const E = preload("res://scripts/cards/economy/economy_support.gd")

static func close(ctx: CardCtx) -> Dictionary:
	E.ensure(ctx)
	var e := ctx.state.ns("econ")
	var stage: int = int(ctx.state.ns("loop").get("stage", 0))
	if int(e.get("month_closed_stage", -1)) == stage:
		return {"ok": true, "err": ""}
	e["month_closed_stage"] = stage
	var expenses: int = int(ctx.rules("economy").get("month_expenses", 30)) * int(e.get("price_index", 100)) / 100
	var amount := mini(expenses, CardCurrency.money(ctx))
	E.transfer(ctx, "player", "world", amount, "g04.reason.expenses")
	ctx.emit(&"notice", ["g04.month.expenses", {"money": amount}])
	var n: int = 0
	for ticket in CardTickets.view(ctx):
		if not bool(ticket["foreign"]) and str(ticket["status"]) in ["active", "overdue"]:
			n += 1
	ctx.emit(&"notice", ["g04.month.tickets", {"n": n}])
	E.sync(ctx)
	return {"ok": true, "err": ""}
