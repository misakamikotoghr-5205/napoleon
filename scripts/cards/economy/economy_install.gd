# G04 登记柜台、鉴定、钱货 DSL 和生命周期钩子。
# 状态只写 econ，修正项视图均只包含可见字段。
class_name CardEconomyInstall
extends RefCounted
const OWNER := "G04"
const E = preload("res://scripts/cards/economy/economy_support.gd")

static func install(engine: CardEngine, ctx: CardCtx) -> void:
	for cmd in [&"counter.open", &"counter.offer", &"counter.answer", &"counter.pick_stock", &"counter.redeem", &"counter.refuse", &"counter.close", &"mg.request", &"mg.report"]:
		engine.register_command(cmd, _command.bind(cmd), OWNER)
	for q in [&"counter", &"stock", &"tickets"]:
		engine.register_query(q, _query.bind(q), OWNER)
	for op in CardDslShapes.EFFECT_OPS.keys():
		if CardDslShapes.EFFECT_OPS[op] == OWNER:
			ctx.ops.register(op, _effect.bind(op), CardDslShapes.shape(op), OWNER)
	for op in CardDslShapes.COND_OPS.keys():
		if CardDslShapes.COND_OPS[op] == OWNER:
			ctx.conds.register(op, _condition.bind(op), CardDslShapes.shape(op, true), OWNER)
	ctx.mods.register(&"price_pct", _price_pct, OWNER)
	ctx.mods.register(&"deal_count", _deal_count, OWNER)
	ctx.mods.register(&"view_section", _view_section, OWNER)
	ctx.mods.register(&"card_view_part", _card_part, OWNER)
	ctx.hooks.on(&"stage_start", _stage, 10, OWNER)
	ctx.hooks.on(&"day_start", _day, 40, OWNER)
	ctx.hooks.on(&"day_end", _day_end, 8, OWNER)
	ctx.hooks.on(&"settle", _settle, 10, OWNER)
	ctx.hooks.on(&"month_close", _month, 10, OWNER)
	ctx.hooks.on(&"year_jump", _year_forfeit, 10, OWNER)
	ctx.hooks.on(&"year_jump", _year_price, 20, OWNER)

static func _command(ctx: CardCtx, args: Dictionary, cmd: StringName) -> Dictionary:
	if str(ctx.state.ns("loop").get("phase", "")) != "day":
		return {"ok": false, "err": "bad_phase"}
	if typeof(args.get("uid")) != TYPE_STRING:
		return {"ok": false, "err": "bad_args"}
	var uid := str(args["uid"])
	if cmd != &"mg.report":
		E.session(ctx, uid).erase("lever_line")
	match cmd:
		&"counter.open": return CardCounter.open(ctx, uid)
		&"counter.offer":
			if typeof(args.get("tier")) == TYPE_STRING:
				return CardCounter.offer(ctx, uid, StringName(str(args["tier"])))
		&"counter.answer":
			if typeof(args.get("accept")) == TYPE_BOOL:
				return CardCounter.answer(ctx, uid, bool(args["accept"]))
		&"counter.pick_stock":
			if typeof(args.get("item")) == TYPE_STRING:
				return CardCounter.pick_stock(ctx, uid, str(args["item"]))
		&"counter.redeem":
			if typeof(args.get("mode")) == TYPE_STRING:
				return CardCounter.redeem(ctx, uid, StringName(str(args["mode"])))
		&"counter.refuse": return CardCounter.refuse(ctx, uid)
		&"counter.close": return CardCounter.close(ctx, uid)
		&"mg.request":
			if typeof(args.get("item", "")) == TYPE_STRING:
				return CardAppraisal.request(ctx, uid, str(args.get("item", "")))
		&"mg.report":
			if typeof(args.get("item", "")) == TYPE_STRING and typeof(args.get("result")) == TYPE_DICTIONARY:
				return CardAppraisal.report(ctx, uid, str(args.get("item", "")), args["result"])
	return {"ok": false, "err": "bad_args"}

static func _query(ctx: CardCtx, args: Dictionary, q: StringName) -> Dictionary:
	match q:
		&"counter": return CardCounter.view(ctx, str(args.get("uid", "")))
		&"stock": return {"items": CardShelf.view(ctx)}
		&"tickets": return {"tickets": CardTickets.view(ctx)}
	return {}

static func _effect(ctx: CardCtx, eff: Dictionary, source: String, op: StringName) -> void:
	E.ensure(ctx)
	var e := ctx.state.ns("econ")
	match op:
		&"money":
			var delta: int = int(eff["delta"])
			E.transfer(ctx, "world" if delta > 0 else "player", "player" if delta > 0 else "world", mini(absi(delta), CardCurrency.money(ctx)) if delta < 0 else delta, str(eff["reason"]), source)
		&"pay": _pay(ctx, eff, source)
		&"item_gain":
			for i in range(maxi(0, int(eff.get("n", 1)))):
				if CardShelf.items(ctx).size() >= CardShelf.cap(ctx):
					break
				e["gain_seq"] = int(e.get("gain_seq", 0)) + 1
				var r := CardItems.generate(ctx, ["c", ctx.abs_day(), source, int(e["gain_seq"]), i], str(eff.get("template", eff.get("cat", ""))))
				if bool(r.get("ok", false)):
					CardShelf.add(ctx, r, source)
		&"item_lose": _lose(ctx, eff)
		&"shop_closed":
			e["shop_closed_until"] = maxi(int(e.get("shop_closed_until", -1)), ctx.abs_day() + maxi(0, int(eff["days"])))
			CardFirsts.mark(ctx, &"shop_closed", {})
		&"price_mod":
			e["price_mods"].append({"scope": str(eff["scope"]), "cat": str(eff.get("cat", "")), "pct": int(eff["pct"]), "until": ctx.abs_day() + int(eff["days"])})
		&"currency_convert": CardCurrency.convert(ctx, str(eff["to"]), int(eff["num"]), int(eff["den"]))
	E.sync(ctx)

static func _pay(ctx: CardCtx, eff: Dictionary, source: String) -> void:
	var amount: int = maxi(0, int(eff["amount"]))
	var money: int = CardCurrency.money(ctx)
	if money >= amount or str(eff["short"]) == "partial":
		if E.transfer(ctx, "player", str(eff["payee"]), mini(money, amount), str(eff["reason"]), source):
			_clear_pending(ctx, source)
	elif str(eff["short"]) == "ladder":
		ctx.state.ns("econ")["pending_payment"] = {"amount": amount, "payee": str(eff["payee"]), "source": source, "reason": str(eff["reason"])}
		ctx.hooks.fire(ctx, &"money_short", {"amount": amount, "payee": str(eff["payee"]), "source": source})
	else:
		fail_payment(ctx, source)

## Explicit default invokes consequences regardless of funds gained during the short panel.
static func fail_payment(ctx: CardCtx, source: String) -> void:
	E.ensure(ctx)
	var e := ctx.state.ns("econ")
	if bool(e.get("short_running", false)):
		return
	e["short_running"] = true
	var uid := source.get_slice("/", 0)
	ctx.run(CardPiles.def_of(ctx, uid).get("effects", {}).get("on_short", []), uid + "/on_short")
	e.erase("short_running")
	_clear_pending(ctx, source)

static func _clear_pending(ctx: CardCtx, source: String) -> void:
	var e := ctx.state.ns("econ")
	var pending_source := str(e.get("pending_payment", {}).get("source", ""))
	if pending_source != "" and (source == pending_source or source.begins_with(pending_source + "/")):
		e.erase("pending_payment")

static func _lose(ctx: CardCtx, eff: Dictionary) -> void:
	var match_item: Dictionary = eff["match"]
	var ids: Array = []
	for id in CardShelf.items(ctx):
		var m := E.meta(ctx, id)
		if (not match_item.has("cat") or str(m["cat"]) == str(match_item["cat"])) and (not match_item.has("template") or str(m["template"]) == str(match_item["template"])):
			ids.append(id)
	var pick := str(match_item.get("pick", "any"))
	if pick != "any":
		ids.sort_custom(func(a: String, b: String) -> bool:
			var av := E.visible_amount(ctx, a)
			var bv := E.visible_amount(ctx, b)
			return a < b if av == bv else (av > bv if pick == "best" else av < bv))
	for i in range(mini(ids.size(), maxi(0, int(eff.get("n", 1))))):
		CardShelf.remove(ctx, str(ids[i]), str(eff["reason"]))

static func _condition(ctx: CardCtx, value, op: StringName) -> bool:
	match op:
		&"money_gte": return CardCurrency.money(ctx) >= int(value)
		&"money_lt": return CardCurrency.money(ctx) < int(value)
		&"currency": return str(ctx.state.ns("econ").get("currency", "fabi")) == str(value)
		&"stock_cat_gte":
			var n: int = 0
			for id in CardShelf.items(ctx):
				if str(E.meta(ctx, id).get("cat", "")) == str(value[0]):
					n += 1
			return n >= int(value[1])
		&"stock_has":
			for id in CardShelf.items(ctx):
				if str(E.meta(ctx, id).get("template", "")) == str(value):
					return true
		&"mg_read": return CardAppraisal.reading(ctx, str(value[0])) == str(value[1])
		&"ticket_open":
			for t in CardTickets.view(ctx):
				if str(t["person"]) == str(value) and str(t["status"]) in ["active", "overdue"] and not bool(t["foreign"]):
					return true
	return false

## price_mod 的 pct 是带符号的增量（+5 涨 5%，-8 落 8%），同时生效的几条相加；
## 合计后不低于 economy.json 的 price_mod_min_pct，卖价不会被压到零。
static func _price_pct(ctx: CardCtx, args: Dictionary) -> int:
	if str(args.get("direction", "")) != "receive":
		return 100
	var delta: int = 0
	for row in ctx.state.ns("econ").get("price_mods", []):
		if int(row["until"]) >= ctx.abs_day() and (str(row["scope"]) == "shelf" or str(row["cat"]) == str(args.get("cat", ""))):
			delta += int(row["pct"])
	return maxi(int(ctx.rules("economy").get("price_mod_min_pct", 10)), 100 + delta)

static func _deal_count(ctx: CardCtx, args: Dictionary) -> int:
	return -100000 if str(args.get("type", "")) == "person" and int(ctx.state.ns("econ").get("shop_closed_until", -1)) >= int(args.get("abs_day", ctx.abs_day())) else 0

static func _view_section(ctx: CardCtx, _args: Dictionary) -> Dictionary:
	return {"money": {"amount": CardCurrency.money(ctx), "currency": str(ctx.state.ns("econ").get("currency", "fabi"))}, "shelf_count": CardShelf.items(ctx).size(), "tickets": CardTickets.view(ctx)}

static func _card_part(ctx: CardCtx, args: Dictionary) -> Dictionary:
	E.ensure(ctx, false)
	var uid := str(args.get("uid", ""))
	var s := E.session(ctx, uid)
	var id := str(s.get("item", CardPiles.card(ctx, uid).get("item_id", "")))
	var out := {"item": E.item_view(ctx, id) if id != "" else null, "asking": int(s.get("asking", -1)),
		"observations": E.meta(ctx, id).get("observations", []).duplicate(), "can_appraise": (id != "" or str(CardPiles.def_of(ctx, uid).get("minigame", "")) != "") and not bool(s.get("blocked", false))}
	if s.has("ticket") and ctx.ledger.contracts.has(s["ticket"]):
		out["days_left"] = maxi(0, int(ctx.ledger.contracts[s["ticket"]]["due_day"]) - ctx.abs_day())
	return out

static func _stage(ctx: CardCtx, args: Dictionary) -> void:
	var stage = args.get("stage", {})
	CardCurrency.apply_stage(ctx, stage if typeof(stage) == TYPE_DICTIONARY else ctx.db.stage(int(stage)))

static func _day(ctx: CardCtx, _args: Dictionary) -> void:
	E.ensure(ctx)
	var e := ctx.state.ns("econ")
	var uids: Array = e["sessions"].keys()
	uids.sort()
	for uid in uids:
		if CardPiles.zone_of(ctx, str(uid)) == &"discard":
			e["sessions"].erase(uid)
			e["appraisals"].erase(uid)
	e["price_mods"] = (e["price_mods"] as Array).filter(func(row: Dictionary) -> bool: return int(row["until"]) >= ctx.abs_day())
	if int(e.get("shop_closed_until", -1)) < ctx.abs_day():
		e.erase("shop_closed_until")
	CardTickets.arrange_redeemers(ctx)
	E.sync(ctx)

static func _day_end(ctx: CardCtx, _args: Dictionary) -> void:
	E.ensure(ctx)
	var e := ctx.state.ns("econ")
	(e["sessions"] as Dictionary).clear()
	(e["appraisals"] as Dictionary).clear()

static func _settle(ctx: CardCtx, _args: Dictionary) -> void:
	CardTickets.tick(ctx)

static func _month(ctx: CardCtx, _args: Dictionary) -> void:
	CardMonthAccounts.close(ctx)

static func _year_forfeit(ctx: CardCtx, _args: Dictionary) -> void:
	CardTickets.forfeit_all(ctx)

static func _year_price(ctx: CardCtx, args: Dictionary) -> void:
	var stage = args.get("to", {})
	var d: Dictionary = stage if typeof(stage) == TYPE_DICTIONARY else ctx.db.stage(int(stage))
	if str(d.get("currency", "fabi")) != str(ctx.state.ns("econ").get("currency", "fabi")):
		for row in ctx.rules("currency").get("conversions", []):
			if str(row.get("to", "")) == str(d.get("currency", "")):
				CardCurrency.convert(ctx, str(row["to"]), int(row["num"]), int(row["den"]))
	ctx.state.ns("econ")["price_index"] = int(d.get("price_index", 100))
