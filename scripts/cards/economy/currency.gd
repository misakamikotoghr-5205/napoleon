# 货币和物价；换币同时重算账户总量，舍入不会破坏账本守恒。
# G04；首发阶段只有法币。
class_name CardCurrency
extends RefCounted
const E = preload("res://scripts/cards/economy/economy_support.gd")

static func apply_stage(ctx: CardCtx, stage: Dictionary) -> void:
	E.ensure(ctx)
	if not ctx.ledger.has_meta("item_templates"):
		ctx.ledger.set_meta("item_templates", CardItems.templates())
	var econ := ctx.state.ns("econ")
	if not bool(econ.get("started", false)):
		E.transfer(ctx, "world", "player", int(ctx.rules("economy").get("start_money", 340)), "g04.reason.start")
		econ["started"] = true
	econ["currency"] = str(stage.get("currency", "fabi"))
	econ["price_index"] = int(stage.get("price_index", 100))
	E.sync(ctx)

static func convert(ctx: CardCtx, to: String, num: int, den: int) -> void:
	if num <= 0 or den <= 0 or to == "":
		return
	E.ensure(ctx)
	var old: int = money(ctx)
	var ledger = ctx.ledger
	var keys: Array = ledger.accounts.keys()
	keys.sort()
	for key in keys:
		ledger.accounts[key] = int(ledger.accounts[key]) * num / den
	ledger.initial_total = ledger.total()
	for rows in [ledger.journal, ledger.contracts, ledger.debts]:
		_scale(rows, num, den)
	for rows in [ctx.state.ns("econ").get("items_meta", {}), ctx.state.ns("econ").get("sessions", {}),
		ctx.state.ns("econ").get("foreign_tickets", []), ctx.state.ns("econ").get("pending_payment", {})]:
		_scale(rows, num, den)
	keys = ledger.debts.keys()
	keys.sort()
	for key in keys:
		var row: Dictionary = ledger.debts[key]
		var paid: int = 0
		for payment in row.get("payments", []):
			paid += int(payment["amount"])
		row["principal"] = int(row["outstanding"]) + paid
	ctx.state.ns("econ")["currency"] = to
	E.sync(ctx)
	ctx.emit(&"money_changed", [old, money(ctx), "g04.reason.currency"])
	CardFirsts.mark(ctx, &"currency", {})

static func money(ctx: CardCtx) -> int:
	if ctx.state == null:
		return 0
	E.ensure(ctx, false)
	return ctx.ledger.balance("player")

static func _scale(tree, num: int, den: int) -> void:
	if typeof(tree) == TYPE_DICTIONARY:
		var keys: Array = tree.keys()
		keys.sort()
		for key in keys:
			if str(key) in ["principal", "outstanding", "amount", "fee", "limit", "paid", "market", "base_price", "asking", "floor", "last_price", "sale_price"] and typeof(tree[key]) == TYPE_INT:
				tree[key] = int(tree[key]) * num / den
			else:
				_scale(tree[key], num, den)
	elif typeof(tree) == TYPE_ARRAY:
		for child in tree:
			_scale(child, num, den)
