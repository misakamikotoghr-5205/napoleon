# G04 认了的付款后果：有钱也不付原账，原牌 on_short 恰好执行一次。
# 嵌套失败付款受重入保护，避免后果递归重复。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/G04/economy_test_support.gd")
const E = preload("res://scripts/cards/economy/economy_support.gd")
func _initialize() -> void:
	var t := T.new(self, "G04_payment_default")
	for funded in [true, false]:
		var ctx := S.ctx()
		ctx.db._cards["p.test.pawn"]["effects"]["on_short"] = [
			{"op":"money", "delta":7, "reason":"g04.reason.test"},
			{"op":"pay", "amount":10000, "payee":"fees", "reason":"g04.reason.fee", "short":"fail"}]
		var uid := S.spawn(ctx)
		E.account(ctx, "fees")
		if not funded:
			E.transfer(ctx, "player", "world", CardCurrency.money(ctx), "g04.reason.test")
		var cash := CardCurrency.money(ctx)
		ctx.state.ns("econ")["pending_payment"] = {"amount":100, "payee":"fees", "source":uid + "/cost", "reason":"g04.reason.fee"}
		CardEconomyInstall.fail_payment(ctx, uid + "/cost")
		t.eq(ctx.ledger.balance("fees"), 0, "explicit default never pays creditor")
		t.eq(CardCurrency.money(ctx), cash + 7, "source on_short executes exactly once despite nested failure")
		t.ok(not ctx.state.ns("econ").has("short_running"), "reentry guard is cleared")
		t.ok(not ctx.state.ns("econ").has("pending_payment"), "resolved default clears matching pending payment")
		S.assert_clean(t, ctx)
	var ctx := S.ctx()
	var uid := S.spawn(ctx)
	ctx.db._cards["p.test.pawn"]["effects"]["on_short"] = [
		{"op":"pay", "amount":10000, "payee":"other", "reason":"g04.reason.fee", "short":"ladder"}]
	ctx.state.ns("econ")["pending_payment"] = {"amount":100, "payee":"fees", "source":uid + "/cost", "reason":"g04.reason.fee"}
	CardEconomyInstall.fail_payment(ctx, uid + "/cost")
	t.eq(ctx.state.ns("econ").get("pending_payment", {}).get("payee"), "other", "new pending payment from on_short is preserved")
	ctx.run([{"op":"money", "delta":20000, "reason":"g04.reason.test"}], "fund")
	var source := str(ctx.state.ns("econ")["pending_payment"]["source"])
	ctx.run([{"op":"pay", "amount":10000, "payee":"other", "reason":"g04.reason.fee", "short":"fail"}], source)
	t.ok(not ctx.state.ns("econ").has("pending_payment"), "successful resumed payment clears matching pending")
	S.assert_clean(t, ctx)
	t.finish()
