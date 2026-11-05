# C04: a buyer picks from the shelf drawer, then the three prices use the receive wording.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C04/support.gd")


func _initialize() -> void:
	var t := T.new(self, "C04_buy")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	t.no_leaks(S.read("buy"), "buy fixture")
	var ctx: Dictionary = S.boot(self, "buy")
	await t.frames(1)
	var panel := S.play(ctx, "c0004")
	await t.frames(2)
	t.ok(not CardAnchors.has(&"a.counter.look"), "buyer has no look button")
	t.ok(not CardAnchors.has(&"a.counter.tier.fair"), "tiers hidden until a piece is picked")
	t.ok(not CardAnchors.has(&"a.counter.stock"), "stock anchor waits for the drawer")
	var pick := S.button(panel, "PickButton")
	t.ok(pick != null, "pick reply")
	if pick != null:
		pick.pressed.emit()
	await t.frames(2)
	# b17: the shelf opens in the host's right drawer (framed, above the table), not inside the
	# counter panel under the table where the end-day button and the hand covered it.
	var drawer: CardPanel = ctx.game.host.drawer_panel()
	t.ok(drawer is CardShelfDrawer, "pick opens the shelf in the host drawer")
	t.ok(drawer != null and not panel.is_ancestor_of(drawer), "shelf is not a child of the counter panel")
	t.ok(drawer != null and drawer.find_child("CloseButton", true, false) == null,
		"framed shelf leaves the close to the drawer frame (no second close)")
	t.ok(t.anchor_ok(&"a.counter.stock"), "stock anchor")
	t.ok(S.button(panel, "Stock_I010") != null, "first shelf cell")
	t.ok(S.button(panel, "Stock_I011") != null, "second shelf cell")
	t.ok(S.button(panel, "Stock_I012") != null, "third shelf cell")
	S.button(panel, "Stock_I010").pressed.emit()
	await t.frames(2)
	t.eq(S.cmds(ctx.mock), [["counter.pick_stock", {"uid": "c0004", "item": "I010"}]], "pick the first scroll")
	t.ok(t.anchor_ok(&"a.counter.tier.fair"), "fair anchor after the pick")
	t.ok(not CardAnchors.has(&"a.counter.stock"), "shelf hides after the pick")
	# Reskin 10-23 (b28): the price is part of the tier text ("开高价 · 130 蚨"), so compare with args.
	var tiers: Dictionary = (panel.get("_cv") as Dictionary).get("tiers", {})
	for tier in ["harsh", "fair", "kind"]:
		var b := S.button(panel, "Tier%s" % tier.capitalize())
		var recv := "c04.tier.%s.receive" % tier
		var pay := "c04.tier.%s.pay" % tier
		var args := {"n": int(tiers.get(tier, 0))}
		t.ok(b != null, tier + " button")
		if b == null:
			continue
		t.eq(b.text, CardText.ui(recv, args), tier + " uses receive wording")
		t.ok(b.text != CardText.ui(pay, args), tier + " is not the pay wording")
		t.ok(b.text.contains(str(args["n"])), tier + " carries its price in the row")
	S.free_ctx(ctx)
	await t.frames(2)
	var ctx2: Dictionary = S.boot(self, "buy")
	await t.frames(1)
	var p2 := S.play(ctx2, "c0004")
	await t.frames(1)
	var stopped := false
	for i in 8:
		var more: bool = p2.autoplay_step()
		await t.frames(1)
		if not more:
			stopped = true
			break
	t.ok(stopped, "buy autoplay stops")
	t.eq(S.cmds(ctx2.mock), [
		["counter.pick_stock", {"uid": "c0004", "item": "I010"}],
		["counter.offer", {"uid": "c0004", "tier": "fair"}],
	], "autoplay picks the first piece then offers fair")
	S.free_ctx(ctx2)
	await t.frames(1)
	await _empty_shelf(t)


# b18: nothing on the shelf suits the buyer -> the pick reply is greyed out with a reason and
# opens no empty drawer; autoplay turns him away instead.
func _empty_shelf(t) -> void:
	var ctx: Dictionary = S.boot(self, "buy")
	var mock: MockCardEngine = ctx.mock
	var key := MockCardEngine.query_key(&"counter", {"uid": "c0004"})
	(mock._fx["queries"][key] as Dictionary)["stock"] = []
	await t.frames(1)
	var panel := S.play(ctx, "c0004")
	await t.frames(2)
	var pick := S.button(panel, "PickButton")
	t.ok(pick != null and pick.disabled, "empty shelf: pick is disabled")
	var found := false
	for n in panel.get("dialog").find_children("*", "Label", true, false):
		if (n as Label).text == CardText.t("c04.reason.shelf_empty"):
			found = (n as Label).is_visible_in_tree()
	t.ok(found, "empty shelf: reason shown")
	panel.on_reply("pick")
	await t.frames(1)
	t.ok(ctx.game.host.drawer_panel() == null, "empty shelf: no empty drawer opens")
	var stopped := false
	for i in 8:
		var more: bool = panel.autoplay_step()
		await t.frames(1)
		if not more:
			stopped = true
			break
	t.ok(stopped, "empty shelf: autoplay stops")
	t.eq(S.cmds(mock), [["counter.refuse", {"uid": "c0004"}]], "empty shelf: autoplay refuses")
	mock = null
	S.free_ctx(ctx)
	await t.frames(2)
