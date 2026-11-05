# G04 柜台 bug（编排 10-25 转来）：出一个柜上付不起的价（或 Enter 默认公道价）时，引擎以前先把客人记成“答应了”，
# 成交再因 money_short 失败——界面念“行，钱我点清了”，钱、货架、手牌却都没动。现在：付不起的价直接回错误码，
# 不算一轮、不扣耐心、不记成答应；CounterView 的 tier_err / accept_err 说出原因，界面据此把回话变灰。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/G04/economy_test_support.gd")
const E = preload("res://scripts/cards/economy/economy_support.gd")


func _initialize() -> void:
	var t := T.new(self, "G04_money_short")
	_offer_unaffordable(t)
	_answer_unaffordable(t)
	_shelf_full(t)
	_affordable_unchanged(t)
	t.finish()


func _drain(c: CardCtx, keep: int) -> void:
	var money := CardCurrency.money(c)
	if money > keep:
		E.transfer(c, "player", "world", money - keep, "g04.reason.test")


func _snapshot(c: CardCtx, uid: String) -> Array:
	return [CardCurrency.money(c), CardShelf.items(c).size(), CardPiles.zone_of(c, uid), E.session(c, uid).duplicate(true)]


func _offer_unaffordable(t) -> void:
	for intent_def in ["p.test.pawn", "p.test.sell"]:
		var c := S.ctx()
		var uid := S.customer(c, intent_def)
		var fair := int(CardPricing.tiers(c, uid)["fair"])
		_drain(c, fair - 1)
		var view := CardCounter.view(c, uid)
		t.eq(str(view["tier_err"]["fair"]), "money_short", "%s: fair tier marked money_short" % intent_def)
		t.eq(str(view["tier_err"]["harsh"]), "" if int(view["tiers"]["harsh"]) <= fair - 1 else "money_short", "%s: harsh tier judged on its own price" % intent_def)
		var before := _snapshot(c, uid)
		var r := CardCounter.offer(c, uid, &"fair")
		t.eq(r, {"ok": false, "err": "money_short"}, "%s: unaffordable offer refused with the reason" % intent_def)
		t.eq(_snapshot(c, uid), before, "%s: money, shelf, hand and session untouched (no round, no patience)" % intent_def)
		t.ok(str(CardCounter.view(c, uid)["last_reply"]) != "accept", "%s: never recorded as accepted" % intent_def)
		t.ok(not str(CardCounter.view(c, uid)["line_key"]).ends_with("#lines.accept"), "%s: never narrated as a done deal" % intent_def)
		var engine_reply := CardEconomyInstall._command(c, {"uid": uid, "tier": "fair"}, &"counter.offer")
		t.eq(str(engine_reply.get("err", "")), "money_short", "%s: the command path returns money_short" % intent_def)
		S.assert_clean(t, c)


func _answer_unaffordable(t) -> void:
	var c := S.ctx()
	var uid := S.customer(c, "p.test.pawn")
	var s := E.session(c, uid)
	s["last_reply"] = "counter"
	s["last_price"] = CardCurrency.money(c) + 50
	t.eq(str(CardCounter.view(c, uid)["accept_err"]), "money_short", "his counter price is beyond the purse")
	var before := _snapshot(c, uid)
	t.eq(CardCounter.answer(c, uid, true), {"ok": false, "err": "money_short"}, "accepting an unaffordable counter is refused")
	t.eq(_snapshot(c, uid), before, "refused accept changes nothing")
	var r := CardCounter.answer(c, uid, false)
	t.ok(bool(r.get("ok", false)), "declining the counter still works")


func _shelf_full(t) -> void:
	var c := S.ctx()
	c.run([{"op": "item_gain", "template": "utensils.bowl", "n": CardShelf.cap(c)}], "test")
	t.eq(CardShelf.items(c).size(), CardShelf.cap(c), "shelf filled")
	var uid := S.customer(c, "p.test.sell")
	t.eq(str(CardCounter.view(c, uid)["tier_err"]["fair"]), "shelf_full", "a full shelf blocks buying in")
	var before := _snapshot(c, uid)
	t.eq(CardCounter.offer(c, uid, &"kind"), {"ok": false, "err": "shelf_full"}, "offer refused: shelf full")
	t.eq(_snapshot(c, uid), before, "shelf-full refusal changes nothing")


func _affordable_unchanged(t) -> void:
	var c := S.ctx()
	var uid := S.customer(c, "p.test.pawn")
	t.eq(CardCounter.view(c, uid)["tier_err"], {"harsh": "", "fair": "", "kind": ""}, "affordable prices carry no error")
	t.eq(str(CardCounter.view(c, uid)["accept_err"]), "", "no counter, no accept error")
	var money := CardCurrency.money(c)
	var r := CardCounter.offer(c, uid, &"kind")
	t.eq(str(r.get("reply", "")), "accept", "the floor-50 pawner accepts the kind price")
	t.ok(CardCurrency.money(c) < money, "the loan was paid out")
	t.ok(CardPiles.zone_of(c, uid) != &"hand", "the guest left the hand after the deal")
