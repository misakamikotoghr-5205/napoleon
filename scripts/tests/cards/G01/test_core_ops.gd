# G01 核心小交付：留牌溢出、补位与四个核心效果操作。
# 主人 G01；合同：§5.2、§7.4.2、§7.9。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")


func _initialize() -> void:
	var t := T.new(self, "G01_core_ops")
	var eng := CardEngine.new(CardEventBus.new())
	var r := eng.new_game({"seed": 101, "only_examples": true, "save_dir": t.user_dir()})
	t.ok(bool(r.get("ok", false)), "new_game")
	var ctx: CardCtx = eng.ctx
	ctx.state.ns("loop")["abs_day"] = 5
	ctx.state.ns("loop")["stage_day"] = 5

	var kept := PackedStringArray()
	for i in range(5):
		var uid := CardPiles.spawn(ctx, "kp.ma_owes", CardIds.ZONE_HAND)
		t.eq(CardPiles.keep(ctx, uid), "", "fill kept %d" % i)
		kept.append(uid)
	var overflow := CardPiles.spawn(ctx, "kp.ma_owes", CardIds.ZONE_HAND)
	t.eq(CardPiles.keep(ctx, overflow), CardIds.ERR_KEPT_FULL, "full kept returns code")
	t.eq(CardPiles.zone_of(ctx, overflow), CardIds.ZONE_PENDING, "overflow enters pending")
	t.eq(CardPiles.card(ctx, overflow).get("status"), "overflow", "overflow status")
	t.eq(CardPiles.overflow_uid(ctx), overflow, "overflow_uid")
	t.eq(ctx.state.ns("loop")["open_panel"], {
		"kind": "kept_full", "args": {"new_uid": overflow},
	}, "kept full panel")
	t.eq(CardPiles.discard(ctx, kept[0]), "", "discard kept")
	t.eq(CardPiles.zone_of(ctx, overflow), CardIds.ZONE_KEPT, "overflow promoted")
	t.eq(CardPiles.card(ctx, overflow).get("status"), "open", "promoted status")
	t.eq(CardPiles.card(ctx, overflow).get("expires_abs_day"), 25, "expiry starts on promotion")
	t.eq(CardPiles.overflow_uid(ctx), "", "overflow cleared")

	ctx.run([{"op": "add_card", "card": "kp.ma_owes", "to": "kept"}], "test/add")
	var pending := CardPiles.overflow_uid(ctx)
	t.ok(pending != "", "add_card kept uses overflow")
	ctx.run([{"op": "remove_card", "match": {"def": "kp.ma_owes"}, "from": "kept", "n": 1}], "test/remove")
	t.eq(CardPiles.overflow_uid(ctx), "", "remove_card opens slot and promotes")
	t.eq(CardPiles.zone_of(ctx, pending), CardIds.ZONE_KEPT, "added card promoted")

	var life := CardPiles.spawn(ctx, "lf.any.coal_out", CardIds.ZONE_HAND)
	ctx.run([{"op": "waive", "match": {"type": "life"}, "n": 1}], "test/waive")
	t.eq(CardPiles.zone_of(ctx, life), CardIds.ZONE_DISCARD, "waive discards")
	t.eq(CardPiles.card(ctx, life).get("status"), "discarded", "waive skips expiry")

	var before := CardPiles.list(ctx, CardIds.ZONE_HAND).size()
	ctx.run([{"op": "extra_deal", "type": "event", "n": 1, "day": "today"}], "test/extra_today")
	t.eq(CardPiles.list(ctx, CardIds.ZONE_HAND).size(), before + 1, "extra deal today")
	ctx.run([{"op": "extra_deal", "type": "event", "n": 1, "day": "tomorrow"}], "test/extra_tomorrow")
	var queue: Array = ctx.state.ns("core")["queue"]
	t.ok(queue.any(func(row: Dictionary) -> bool: return str(row.get("pool", "")) == "event"), "extra deal queued")
	ctx.state.ns("loop")["abs_day"] = 6
	CardComposer.compose(ctx)
	queue = ctx.state.ns("core")["queue"]
	t.ok(not queue.any(func(row: Dictionary) -> bool: return str(row.get("pool", "")) == "event"), "queued extra consumed")

	for bad in [
		{"op": "add_card", "to": "hand"},
		{"op": "remove_card", "from": "hand"},
		{"op": "waive"},
		{"op": "extra_deal", "day": "today"},
	]:
		t.ok(ctx.ops.validate(bad) != "", "bad core op rejected")
	t.eq(t.find_floats(ctx.state.data), PackedStringArray(), "no floats")
	eng.bus.free()
	t.finish()
