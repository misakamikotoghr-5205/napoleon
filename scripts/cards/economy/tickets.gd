# 整数当票和倒计时，跨年满当；外来当票独立记录，绝不动钱。
# G04；查封和街头期间不安排来赎的人，账本仍照常倒计时。
class_name CardTickets
extends RefCounted
const E = preload("res://scripts/cards/economy/economy_support.gd")

static func open(ctx: CardCtx, uid: String, item_id: String, principal: int, term_days: int) -> int:
	E.ensure(ctx)
	var d := CardPiles.def_of(ctx, uid)
	var person := str(d.get("person", "customer"))
	E.account(ctx, person)
	var old: int = CardCurrency.money(ctx)
	var tid: String = ctx.ledger.open_pawn(person, [item_id], principal, ctx.abs_day(), term_days, "", false)
	if tid == "":
		return 0
	var no: int = int(ctx.ledger.contracts[tid]["no"])
	ctx.state.ns("econ")["ticket_people"][tid] = person
	E.sync(ctx)
	ctx.emit(&"money_changed", [old, CardCurrency.money(ctx), "g04.reason.pawn_out"])
	CardFirsts.mark(ctx, &"ticket", {"no": no, "person": person})
	return no

static func tick(ctx: CardCtx) -> void:
	E.ensure(ctx)
	var changed: Array = ctx.ledger.tick_contracts(ctx.abs_day())
	for tid in changed:
		var c: Dictionary = ctx.ledger.contracts[tid]
		if str(c["status"]) == "forfeited":
			for id in c["item_ids"]:
				if str(ctx.ledger.items[id]["location"]) == "stock":
					E.meta(ctx, id)["on_shelf_since"] = ctx.abs_day()
					CardFirsts.mark(ctx, &"shelf", {})
		ctx.emit(&"notice", ["g04.ticket." + str(c["status"]), {"no": int(c["no"])}])
	E.sync(ctx)

static func forfeit_all(ctx: CardCtx) -> Array:
	E.ensure(ctx)
	var out: Array = []
	var ids: Array = ctx.ledger.contracts.keys()
	ids.sort()
	for tid in ids:
		var c: Dictionary = ctx.ledger.contracts[tid]
		if str(c["status"]) not in ["active", "overdue"]:
			continue
		c["status"] = "forfeited"
		for id in c["item_ids"]:
			ctx.ledger.items[id]["pledged_to"] = ""
			if str(ctx.ledger.items[id]["location"]) == "pawnbox":
				ctx.ledger.move_item(id, "stock", "player", "year_forfeit")
				E.meta(ctx, id)["on_shelf_since"] = ctx.abs_day()
				CardFirsts.mark(ctx, &"shelf", {})
		out.append(int(c["no"]))
	E.sync(ctx)
	if not out.is_empty():
		ctx.emit(&"notice", ["g04.month.forfeit", {"n": out.size()}])
	return out

static func view(ctx: CardCtx) -> Array:
	E.ensure(ctx, false)
	var out: Array = []
	var ids: Array = ctx.ledger.contracts.keys()
	ids.sort()
	for tid in ids:
		var c: Dictionary = ctx.ledger.contracts[tid]
		out.append({"no": int(c["no"]), "person": str(c["borrower"]), "item": str(c["item_ids"][0]),
			"principal": int(c["principal"]), "days_left": maxi(0, int(c["due_day"]) - ctx.abs_day()),
			"status": str(c["status"]), "foreign": false})
	out.append_array(ctx.state.ns("econ").get("foreign_tickets", []).duplicate(true))
	return out

static func arrange_redeemers(ctx: CardCtx) -> void:
	E.ensure(ctx)
	var econ := ctx.state.ns("econ")
	if int(econ.get("shop_closed_until", -1)) >= ctx.abs_day() or str(ctx.state.ns("loop").get("mode", "shop")) == "street":
		return
	var rules: Dictionary = ctx.rules("economy").get("redeem", {})
	for ticket in view(ctx):
		if bool(ticket["foreign"]) or str(ticket["status"]) not in ["active", "overdue"] or int(ticket["days_left"]) > 0:
			continue
		var tid := "t%04d" % int(ticket["no"])
		var previous := str(econ["redeem_visits"].get(tid, ""))
		if previous != "" and CardPiles.zone_of(ctx, previous) != &"discard":
			continue
		if ctx.draw("c.redeem.come", [int(ticket["no"]), ctx.abs_day()]) * int(rules.get("come_den", 3)) >= int(rules.get("come_num", 2)):
			continue
		var def_id := "p.any.redeem"
		for id in ctx.db.ids_of(&"person"):
			var d := ctx.db.def(id)
			if str(d.get("intent", "")) == "redeem" and str(d.get("person", "")) == str(ticket["person"]):
				def_id = id
				break
		if ctx.db.has(def_id):
			econ["redeem_visits"][tid] = CardPiles.spawn(ctx, def_id, &"hand", {"vars": {"ticket_no": int(ticket["no"]), "person": str(ticket["person"])}})

static func foreign(ctx: CardCtx, uid: String) -> void:
	E.ensure(ctx)
	var d := CardPiles.def_of(ctx, uid)
	var ticket: Dictionary = d.get("ticket", {})
	var no: int = int(ticket.get("no", d.get("number", d.get("ticket_no", 0))))
	for row in ctx.state.ns("econ")["foreign_tickets"]:
		if int(row["no"]) == no:
			return
	ctx.state.ns("econ")["foreign_tickets"].append({"no": no, "person": str(ticket.get("person", d.get("holder", d.get("person", "")))),
		"item": "", "principal": int(ticket.get("principal", 0)), "days_left": -1, "status": "recorded", "foreign": true})
	CardFirsts.mark(ctx, &"ticket", {"no": no})
	E.sync(ctx)
