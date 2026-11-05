# 钱货共用工具：只写 econ，旧账本产生的物品历史立即清洗为 ASCII。
# G04；账本对象按状态实例重新绑定，存档只保留整数快照。
extends RefCounted
const Ledger = preload("res://scripts/cards/economy/card_ledger.gd")

static func ensure(ctx: CardCtx, initialize: bool = true) -> void:
	var e := ctx.state.ns("econ")
	if ctx.ledger == null or int(ctx.ledger.get_meta("state_id", -1)) != ctx.state.get_instance_id():
		ctx.ledger = Ledger.new()
		if e.has("ledger"):
			ctx.ledger.from_dict(e["ledger"])
		else:
			ctx.ledger.open_account("player", 0)
			ctx.ledger.open_account("world", 1000000000)
		ctx.ledger.set_meta("state_id", ctx.state.get_instance_id())
	if not initialize:
		return
	for key in ["items_meta", "sessions", "ticket_people", "redeem_visits", "appraisals"]:
		if not e.has(key):
			e[key] = {}
	for key in ["foreign_tickets", "price_mods"]:
		if not e.has(key):
			e[key] = []
	var ticket: Dictionary = ctx.rules("economy").get("ticket", {})
	ctx.ledger.rate_pct = int(ticket.get("rate_pct_month", 3))
	ctx.ledger.storage_permille = int(ticket.get("storage_permille_month", 5))
	ctx.ledger.grace_days = int(ticket.get("grace_days", 3))

static func sync(ctx: CardCtx) -> void:
	ctx.state.ns("econ")["ledger"] = ctx.ledger.to_dict()

static func account(ctx: CardCtx, name: String) -> void:
	ensure(ctx)
	if not ctx.ledger.accounts.has(name):
		ctx.ledger.open_account(name, 0)

static func transfer(ctx: CardCtx, from: String, to: String, amount: int, reason: String, ref: String = "") -> bool:
	ensure(ctx)
	account(ctx, from)
	account(ctx, to)
	var old: int = ctx.ledger.balance("player")
	var ok: bool = amount == 0 or ctx.ledger.transfer(from, to, amount, reason, ref) != ""
	sync(ctx)
	var now: int = ctx.ledger.balance("player")
	if old != now:
		ctx.emit(&"money_changed", [old, now, reason])
	return ok

static func fund(ctx: CardCtx, name: String, amount: int) -> void:
	account(ctx, name)
	var missing: int = maxi(0, amount - ctx.ledger.balance(name))
	if missing > 0:
		transfer(ctx, "world", name, missing, "g04.reason.fund")

static func session(ctx: CardCtx, uid: String) -> Dictionary:
	return ctx.state.ns("econ").get("sessions", {}).get(uid, {})

static func meta(ctx: CardCtx, item: String) -> Dictionary:
	return ctx.state.ns("econ").get("items_meta", {}).get(item, {})

static func visible_amount(ctx: CardCtx, item: String) -> int:
	var m := meta(ctx, item)
	var band: int = clampi(int(m.get("condition_permille", 1000)) / 200, 0, 4)
	# TODO(design): conservative visible estimate uses base price and displayed condition band only.
	return maxi(1, int(m.get("base_price", 1)) * int(ctx.state.ns("econ").get("price_index", 100)) * (band + 1) / 500)

static func item_view(ctx: CardCtx, id: String) -> Dictionary:
	var m := meta(ctx, id)
	return {"item": id, "template": str(m.get("template", "")), "cat": str(m.get("cat", "")),
		"art": str(m.get("art", "")), "condition_word": clampi(int(m.get("condition_permille", 0)) / 200, 0, 4),
		"observations": m.get("observations", []).duplicate(), "on_shelf_since": int(m.get("on_shelf_since", -1))}

static func range_int(ctx: CardCtx, domain: String, key: Array, bounds: Array) -> int:
	var low: int = int(bounds[0]) if bounds.size() > 0 else 0
	var high: int = int(bounds[1]) if bounds.size() > 1 else low
	return low + int(ctx.draw(domain, key) * (maxi(low, high) - low + 1))

static func end(ctx: CardCtx, uid: String, outcome: StringName, actions: Array = []) -> void:
	sync(ctx)
	var event := "on_accept" if outcome == &"resolved" else ("on_refuse" if outcome == &"refused" else "on_leave")
	var d := CardPiles.def_of(ctx, uid)
	ctx.run(d.get("effects", {}).get(event, []), uid + "/" + event)
	CardPiles.resolve(ctx, uid, outcome, {"almanac": actions})
	ctx.state.ns("econ").get("sessions", {}).erase(uid)
	ctx.state.ns("econ").get("appraisals", {}).erase(uid)
