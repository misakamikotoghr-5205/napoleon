# C04: redeem by the rule or squeeze. A sold pledge only offers compensate / buy_back.
# ticket.status "sold" is the value this panel treats as already sold.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C04/support.gd")


func _initialize() -> void:
	var t := T.new(self, "C04_redeem")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	t.no_leaks(S.read("redeem_by_rule"), "redeem_by_rule")
	t.no_leaks(S.read("redeem_sold"), "redeem_sold")
	await _modes(t, "redeem_by_rule", "c0008", ["by_rule", "squeeze"], ["compensate", "buy_back"])
	await _modes(t, "redeem_sold", "c0009", ["compensate", "buy_back"], ["by_rule", "squeeze"])
	var ctx: Dictionary = S.boot(self, "redeem_by_rule")
	await t.frames(1)
	var panel := S.play(ctx, "c0008")
	await t.frames(1)
	var stopped := false
	for i in 4:
		var more: bool = panel.autoplay_step()
		await t.frames(1)
		if not more:
			stopped = true
			break
	t.ok(stopped, "redeem autoplay stops")
	t.eq(S.cmds(ctx.mock), [["counter.redeem", {"uid": "c0008", "mode": "by_rule"}]], "autoplay redeems by rule")
	S.free_ctx(ctx)
	await t.frames(1)


func _modes(t, fx: String, uid: String, shown: Array, hidden: Array) -> void:
	var ctx: Dictionary = S.boot(self, fx)
	await t.frames(1)
	var panel := S.play(ctx, uid)
	await t.frames(2)
	t.ok(t.anchor_ok(&"a.counter.redeem"), fx + " redeem anchor")
	t.ok(not CardAnchors.has(&"a.counter.stock"), fx + " no shelf")
	t.ok(not CardAnchors.has(&"a.counter.tier.fair"), fx + " no price tiers")
	for mode in shown:
		t.ok(S.button(panel, "Redeem_%s" % mode) != null, fx + " shows " + mode)
	for mode in hidden:
		t.ok(S.button(panel, "Redeem_%s" % mode) == null, fx + " hides " + mode)
	S.free_ctx(ctx)
	await t.frames(2)
	for mode in shown:
		var c2: Dictionary = S.boot(self, fx)
		await t.frames(1)
		var p2 := S.play(c2, uid)
		await t.frames(2)
		S.button(p2, "Redeem_%s" % mode).pressed.emit()
		await t.frames(1)
		t.eq(S.cmds(c2.mock), [["counter.redeem", {"uid": uid, "mode": mode}]], fx + " sends " + mode)
		S.free_ctx(c2)
		await t.frames(1)
