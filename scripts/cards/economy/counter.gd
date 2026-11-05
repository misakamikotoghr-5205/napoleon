# 柜台当卖买赎、拒绝和体面离开；牌的去留只经 CardPiles。
# G04；CounterView 不包含底价、真值、耐心或概率。说破（鉴定改版）只经 line_key 的一句回话和改过的开价露出来。
class_name CardCounter
extends RefCounted
const E = preload("res://scripts/cards/economy/economy_support.gd")

static func open(ctx: CardCtx, uid: String) -> Dictionary:
	E.ensure(ctx)
	var d := CardPiles.def_of(ctx, uid)
	var intent := str(d.get("intent", ""))
	if CardPiles.zone_of(ctx, uid) != &"hand" or intent not in ["pawn", "sell", "buy", "redeem"]:
		return {"ok": false, "err": "bad_args"}
	if not E.session(ctx, uid).is_empty():
		return view(ctx, uid)
	var s := {"intent": intent, "item": "", "person": str(d.get("person", "customer")), "round": 0,
		"asking": 0, "floor": 0, "last_reply": "", "last_price": 0, "impatience": str(d.get("impatience", "leave")),
		"patience": E.range_int(ctx, "c.cust.patience", [ctx.abs_day(), uid], d.get("patience_min", [60, 120])), "blocked": false}
	if intent in ["pawn", "sell"]:
		var spec: Dictionary = d.get("item", {})
		var result := CardItems.generate(ctx, ["c", ctx.abs_day(), uid], str(spec.get("template", spec.get("cat", ""))))
		if not bool(result.get("ok", false)):
			return result
		s["item"] = str(result["item"])
		s["blocked"] = ctx.mods.any_true(ctx, &"intake_blocked", {"cat": str(E.meta(ctx, s["item"])["cat"])})
		var amount: int = E.visible_amount(ctx, s["item"])
		s["asking"] = maxi(1, amount * E.range_int(ctx, "c.cust.asking", [ctx.abs_day(), uid], d.get("asking", {}).get("pct", [90, 120])) / 100)
		s["floor"] = maxi(1, amount * E.range_int(ctx, "c.cust.floor", [ctx.abs_day(), uid], d.get("floor", {}).get("pct", [55, 75])) / 100)
	elif intent == "buy":
		var cats: Array = d.get("want", {}).get("cats", [])
		var pick: int = mini(cats.size() - 1, int(ctx.draw("c.cust.want", [ctx.abs_day(), uid]) * cats.size()))
		s["want"] = str(cats[pick]) if not cats.is_empty() else ""
		s["budget_pct"] = E.range_int(ctx, "c.cust.floor", [ctx.abs_day(), uid], d.get("want", {}).get("budget_pct", [80, 130]))
		CardFirsts.mark(ctx, &"buyer", {"uid": uid, "person": str(s["person"])})
	else:
		var card := CardPiles.card(ctx, uid)
		var no: int = int(card.get("vars", {}).get("ticket_no", card.get("vars", {}).get("no", 0)))
		s["ticket"] = "t%04d" % no
		if not ctx.ledger.contracts.has(s["ticket"]):
			return {"ok": false, "err": "no_ticket"}
		s["person"] = str(ctx.ledger.contracts[s["ticket"]]["borrower"])
		s["item"] = str(ctx.ledger.contracts[s["ticket"]]["item_ids"][0])
	ctx.state.ns("econ")["sessions"][uid] = s
	CardFirsts.mark(ctx, &"counter", {"uid": uid, "person": str(s["person"])})
	if intent == "redeem":
		CardFirsts.mark(ctx, &"redeem", {"uid": uid, "person": str(s["person"]), "no": int(ctx.ledger.contracts[s["ticket"]]["no"])})
	E.sync(ctx)
	return view(ctx, uid)

static func offer(ctx: CardCtx, uid: String, tier: StringName) -> Dictionary:
	var s := E.session(ctx, uid)
	if CardPiles.zone_of(ctx, uid) != &"hand" or s.is_empty() or tier not in [&"harsh", &"fair", &"kind"] or str(s["intent"]) == "redeem":
		return {"ok": false, "err": "bad_args"}
	if bool(s["blocked"]):
		return {"ok": false, "err": "intake_blocked"}
	if str(s["item"]) == "":
		return {"ok": false, "err": "pick_stock"}
	# A price the shop cannot pay out (or a full shelf) is refused before the customer hears it:
	# no round, no patience, and never a recorded "accept" for a deal that cannot happen.
	var price := int(CardPricing.tiers(ctx, uid)[str(tier)])
	var why := deal_error(ctx, uid, price)
	if why != "":
		return {"ok": false, "err": why}
	s["round"] = int(s["round"]) + 1
	var action := CardCustomer.spend_patience(ctx, uid, int(ctx.rules("economy").get("patience", {}).get("offer_min", 10)))
	if action == &"leave":
		return _leave(ctx, uid)
	var r := CardCustomer.reply(ctx, uid, price)
	if r["reply"] == "accept":
		return _accept(ctx, uid, int(r["price"]))
	s["last_reply"] = str(r["reply"])
	s["last_price"] = int(r["price"])
	if r["reply"] == "leave":
		return _leave(ctx, uid)
	return {"ok": true, "err": "", "reply": "counter", "price": int(r["price"])}

static func answer(ctx: CardCtx, uid: String, accept: bool) -> Dictionary:
	var s := E.session(ctx, uid)
	if CardPiles.zone_of(ctx, uid) != &"hand" or s.is_empty() or str(s.get("last_reply", "")) != "counter":
		return {"ok": false, "err": "bad_args"}
	if accept:
		var why := deal_error(ctx, uid, int(s["last_price"]))
		if why != "":
			return {"ok": false, "err": why}
	var action := CardCustomer.spend_patience(ctx, uid, int(ctx.rules("economy").get("patience", {}).get("counter_min", 10)))
	if action == &"leave":
		return _leave(ctx, uid)
	if accept:
		return _accept(ctx, uid, int(s["last_price"]))
	if int(s["round"]) >= int(ctx.rules("economy").get("max_rounds", 5)):
		return _leave(ctx, uid)
	s["last_reply"] = ""
	return {"ok": true, "err": "", "reply": "counter", "price": int(s["last_price"])}

static func pick_stock(ctx: CardCtx, uid: String, item_id: String) -> Dictionary:
	var s := E.session(ctx, uid)
	if CardPiles.zone_of(ctx, uid) != &"hand" or s.is_empty() or str(s["intent"]) != "buy" or not CardShelf.items(ctx).has(item_id):
		return {"ok": false, "err": "bad_args"}
	if str(s.get("want", "")) != "" and str(E.meta(ctx, item_id).get("cat", "")) != str(s["want"]):
		return {"ok": false, "err": "wrong_category"}
	s["item"] = item_id
	s["asking"] = E.visible_amount(ctx, item_id)
	s["floor"] = maxi(1, int(E.meta(ctx, item_id).get("market", 0)) * int(ctx.state.ns("econ").get("price_index", 100)) * int(s["budget_pct"]) / 10000)
	E.fund(ctx, str(s["person"]), int(s["floor"]))
	return {"ok": true, "err": ""}

static func redeem(ctx: CardCtx, uid: String, mode: StringName) -> Dictionary:
	var s := E.session(ctx, uid)
	if CardPiles.zone_of(ctx, uid) != &"hand" or s.is_empty() or str(s["intent"]) != "redeem" or mode not in [&"by_rule", &"squeeze", &"compensate", &"buy_back"]:
		return {"ok": false, "err": "bad_args"}
	var tid := str(s["ticket"])
	var c: Dictionary = ctx.ledger.contracts.get(tid, {})
	if str(c.get("status", "")) not in ["active", "overdue"]:
		return {"ok": false, "err": "ticket_closed"}
	var id := str(s["item"])
	var location := str(ctx.ledger.items[id]["location"])
	var sold: bool = location.begins_with("npc:")
	if mode in [&"by_rule", &"squeeze"] and location != "pawnbox":
		return {"ok": false, "err": "original_missing"}
	if (mode in [&"compensate", &"buy_back"]) != sold:
		return {"ok": false, "err": "original_missing" if sold else "original_present"}
	var rules: Dictionary = ctx.rules("economy").get("redeem", {})
	if mode == &"compensate":
		var amount: int = int(c["principal"]) * int(rules.get("compensate_pct", 120)) / 100
		if not E.transfer(ctx, "player", str(c["borrower"]), amount, "g04.reason.compensate", tid):
			return {"ok": false, "err": "money_short"}
		c["status"] = "compensated"
	else:
		if mode == &"buy_back":
			var amount: int = maxi(1, int(E.meta(ctx, id).get("sale_price", E.visible_amount(ctx, id))))
			if not E.transfer(ctx, "player", str(ctx.ledger.items[id]["owner"]), amount, "g04.reason.buy_back", tid):
				return {"ok": false, "err": "money_short"}
			ctx.ledger.move_item(id, "pawnbox", str(c["borrower"]), "buy_back")
		var amount: int = ctx.ledger.redeem_amount(tid, ctx.abs_day())
		if mode == &"squeeze":
			amount = amount * (100 + int(rules.get("squeeze_pct", 20))) / 100
		E.fund(ctx, str(c["borrower"]), amount)
		E.transfer(ctx, str(c["borrower"]), "player", amount, "g04.reason.redeem_in", tid)
		ctx.ledger.move_item(id, "npc:" + str(c["borrower"]), str(c["borrower"]), "redeem")
		c["status"] = "redeemed"
		if mode == &"squeeze":
			# TODO(design): minimal reputation/conscience cost pending authored consequences.
			ctx.run([{"op": "rep", "delta": -1}, {"op": "conscience", "delta": -1}], uid + "/squeeze")
	ctx.ledger.items[id]["pledged_to"] = ""
	CardFirsts.mark(ctx, &"redeem", {"uid": uid, "no": int(c["no"]), "person": str(c["borrower"])})
	E.end(ctx, uid, &"resolved", ["redeem", "trade"])
	return {"ok": true, "err": "", "reply": "accept"}

static func refuse(ctx: CardCtx, uid: String) -> Dictionary:
	if CardPiles.zone_of(ctx, uid) != &"hand" or str(CardPiles.def_of(ctx, uid).get("intent", "")) not in ["pawn", "sell", "buy", "redeem"]:
		return {"ok": false, "err": "bad_args"}
	E.ensure(ctx)
	E.end(ctx, uid, &"refused")
	return {"ok": true, "err": ""}

static func close(ctx: CardCtx, uid: String) -> Dictionary:
	return {"ok": not E.session(ctx, uid).is_empty(), "err": "" if not E.session(ctx, uid).is_empty() else "bad_args"}

static func view(ctx: CardCtx, uid: String) -> Dictionary:
	E.ensure(ctx, false)
	var s := E.session(ctx, uid)
	if s.is_empty():
		return {"ok": false, "err": "bad_phase"}
	var id := str(s["item"])
	var d := CardPiles.def_of(ctx, uid)
	var stock: Array = []
	if str(s["intent"]) == "buy":
		for row in CardShelf.view(ctx):
			if str(s.get("want", "")) == "" or str(row["cat"]) == str(s["want"]):
				stock.append(str(row["item"]))
	var ticket: Dictionary = {}
	if s.has("ticket"):
		for row in CardTickets.view(ctx):
			if int(row["no"]) == int(ctx.ledger.contracts[s["ticket"]]["no"]) and not bool(row["foreign"]):
				ticket = row
	var line := "g04.counter.intake_blocked" if bool(s["blocked"]) else str(d.get("id", "")) + "#lines." + (str(s["last_reply"]) if str(s["last_reply"]) != "" else "greet")
	# Level B: right after an appraisal settles, the customer's reaction (g04.counter.lever.*); cleared by the next command.
	if str(s.get("lever_line", "")) != "":
		line = str(s["lever_line"])
	var tiers := CardPricing.tiers(ctx, uid)
	tiers.erase("direction")
	return {"ok": true, "err": "", "uid": uid, "person": str(s["person"]), "intent": str(s["intent"]),
		"item": E.item_view(ctx, id) if id != "" else null, "asking": int(s["asking"]), "tiers": tiers,
		"direction": "receive" if str(s["intent"]) == "buy" else "pay", "round": int(s["round"]),
		"last_reply": str(s["last_reply"]), "last_price": int(s["last_price"]), "line_key": line,
		"tier_err": _tier_errors(ctx, uid, tiers), "accept_err": deal_error(ctx, uid, int(s["last_price"])) if str(s["last_reply"]) == "counter" else "",
		"can_appraise": id != "" and not bool(s["blocked"]), "stock": stock, "ticket": ticket if not ticket.is_empty() else null, "choices": CardChoices.options(ctx, uid)}

## Why a deal at this price cannot go through right now ("" = it can): the shop pays out for pawn / sell.
static func deal_error(ctx: CardCtx, uid: String, price: int) -> String:
	var s := E.session(ctx, uid)
	var intent := str(s.get("intent", ""))
	if intent == "sell" and CardShelf.items(ctx).size() >= CardShelf.cap(ctx):
		return "shelf_full"
	if intent in ["pawn", "sell"] and CardCurrency.money(ctx) < price:
		return "money_short"
	if intent == "buy" and not CardShelf.items(ctx).has(str(s.get("item", ""))):
		return "stock_missing"
	return ""

## The customer said yes: record it only if the deal really happens (a refused deal is never narrated as done).
static func _accept(ctx: CardCtx, uid: String, price: int) -> Dictionary:
	var s := E.session(ctx, uid)
	var before := [str(s.get("last_reply", "")), int(s.get("last_price", 0))]
	s["last_reply"] = "accept"
	s["last_price"] = price
	var r := _deal(ctx, uid, price)
	if not bool(r.get("ok", false)) and not E.session(ctx, uid).is_empty():
		s["last_reply"] = str(before[0])
		s["last_price"] = int(before[1])
	return r

static func _deal(ctx: CardCtx, uid: String, price: int) -> Dictionary:
	var s := E.session(ctx, uid)
	var intent := str(s["intent"])
	var id := str(s["item"])
	if intent == "buy" and not CardShelf.items(ctx).has(id):
		return {"ok": false, "err": "stock_missing"}
	if intent == "sell" and CardShelf.items(ctx).size() >= CardShelf.cap(ctx):
		return {"ok": false, "err": "shelf_full"}
	var action := "pawn_in"
	if intent == "pawn":
		var no := CardTickets.open(ctx, uid, id, price, int(CardPiles.def_of(ctx, uid).get("term_days", ctx.rules("economy").get("ticket", {}).get("term_days", 15))))
		if no == 0:
			return {"ok": false, "err": "money_short"}
	elif intent == "sell":
		if not E.transfer(ctx, "player", str(s["person"]), price, "g04.reason.buy_out", uid):
			return {"ok": false, "err": "money_short"}
		CardShelf.add(ctx, {"item": id}, "buy_in")
		action = "buy_in"
	else:
		if not E.transfer(ctx, str(s["person"]), "player", price, "g04.reason.sell_in", uid):
			return {"ok": false, "err": "money_short"}
		var pledged := str(ctx.ledger.items[id].get("pledged_to", ""))
		if ctx.ledger.contracts.has(pledged):
			ctx.ledger.contracts[pledged]["unauthorized_disposal"] = true
		ctx.ledger.move_item(id, "npc:" + str(s["person"]), str(s["person"]), "sell_out")
		E.meta(ctx, id)["sale_price"] = price
		action = "sell_out"
	E.end(ctx, uid, &"resolved", [action, "trade"])
	return {"ok": true, "err": "", "reply": "accept", "price": price}

## Per tier, why that price cannot be offered now ("" = it can); the panel disables the reply and says why.
static func _tier_errors(ctx: CardCtx, uid: String, tiers: Dictionary) -> Dictionary:
	var out := {}
	for tier in ["harsh", "fair", "kind"]:
		out[tier] = deal_error(ctx, uid, int(tiers.get(tier, 0))) if str(E.session(ctx, uid).get("item", "")) != "" else ""
	return out

static func _leave(ctx: CardCtx, uid: String) -> Dictionary:
	E.end(ctx, uid, &"left")
	return {"ok": true, "err": "", "reply": "leave", "price": 0}
