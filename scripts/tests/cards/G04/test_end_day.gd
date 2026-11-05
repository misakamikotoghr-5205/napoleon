# G04 合同1.2：打烊关闭会话，不把未成交报价变成交易。
# 查封一天抑制次日随机人物及来赎；当票保留，之后仍会来赎。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/G04/economy_test_support.gd")
const E = preload("res://scripts/cards/economy/economy_support.gd")
func _initialize() -> void:
	var t := T.new(self, "G04_end_day")
	_counter_cleanup(t)
	_closure_redeem(t)
	t.finish()

func _counter_cleanup(t) -> void:
	var ctx := S.ctx()
	var uid := ""
	for attempt in range(10):
		uid = S.customer(ctx)
		E.session(ctx, uid)["floor"] = 1000000
		var result := CardCounter.offer(ctx, uid, &"harsh")
		if str(result.get("reply", "")) == "counter":
			break
	t.ok(not E.session(ctx, uid).is_empty(), "offered negotiation remains open before end")
	var item := str(E.session(ctx, uid).get("item", ""))
	CardAppraisal.request(ctx, uid, item)
	var money := CardCurrency.money(ctx)
	var stock := CardShelf.items(ctx)
	var tickets := CardTickets.view(ctx)
	ctx.hooks.fire(ctx, &"day_end", {})
	t.ok(ctx.state.ns("econ")["sessions"].is_empty(), "all counter sessions are closed at priority eight")
	t.ok(ctx.state.ns("econ")["appraisals"].is_empty(), "pending appraisal is cancelled without report")
	t.eq(CardCurrency.money(ctx), money, "unaccepted offer causes no cash movement")
	t.eq(CardShelf.items(ctx), stock, "unaccepted offer changes no stock")
	t.eq(CardTickets.view(ctx), tickets, "unaccepted offer creates no ticket")
	t.eq(CardPiles.zone_of(ctx, uid), &"hand", "person disposition is reserved for G02 priority ten")
	t.eq(CardAppraisal.report(ctx, uid, item, S.result()).get("err"), "bad_args", "late cancelled appraisal cannot affect the day")
	S.assert_clean(t, ctx)

func _closure_redeem(t) -> void:
	var ctx := S.ctx()
	var tid := S.pawn(ctx)
	var due_day: int = int(ctx.ledger.contracts[tid]["due_day"])
	ctx.db._rules["economy"]["redeem"].merge({"come_num":1,"come_den":1}, true)
	ctx.state.ns("loop")["abs_day"] = due_day
	CardTickets.arrange_redeemers(ctx)
	var visit := str(ctx.state.ns("econ")["redeem_visits"][tid])
	CardCounter.open(ctx, visit)
	var contract: Dictionary = ctx.ledger.contracts[tid].duplicate(true)
	var money := CardCurrency.money(ctx)
	ctx.hooks.on(&"day_end", func(context: CardCtx, _args: Dictionary) -> void:
		CardPiles.resolve(context, visit, &"left"), 10, "test_G02")
	ctx.hooks.fire(ctx, &"day_end", {})
	t.eq(ctx.ledger.contracts[tid], contract, "unreceived redeemer leaves the contract unchanged")
	t.eq(CardCurrency.money(ctx), money, "unreceived redeemer pays no money")
	ctx.run([{"op":"shop_closed","days":1}], "test_G06_prison")
	ctx.state.ns("loop")["abs_day"] = due_day + 1
	ctx.hooks.fire(ctx, &"day_start", {})
	ctx.mods.register(&"pool_rows", _pool_rows, "test")
	ctx.db._rules["deal"].merge({"event":{"per_day":0},"news":{"num":0,"den":1}}, true)
	t.eq(CardComposer.project(ctx, ctx.abs_day()), PackedStringArray(), "shop closed blocks random person cards")
	t.eq(str(ctx.state.ns("econ")["redeem_visits"][tid]), visit, "shop closed blocks next-day redeem arrival")
	t.eq(CardPiles.zone_of(ctx, visit), &"discard", "previous redeem card stays disposed")
	ctx.hooks.fire(ctx, &"settle", {})
	t.eq(ctx.ledger.contracts[tid]["status"], "overdue", "ticket still counts down during closure")
	ctx.state.ns("loop")["abs_day"] = due_day + 2
	ctx.hooks.fire(ctx, &"day_start", {})
	t.ok(str(ctx.state.ns("econ")["redeem_visits"][tid]) != visit, "unreceived redeemer can return after reopening")
	S.assert_clean(t, ctx)

static func _pool_rows(_ctx: CardCtx, args: Dictionary) -> Array:
	return [["p.test.pawn", 1000]] if str(args.get("pool", "")) == "person" else []
