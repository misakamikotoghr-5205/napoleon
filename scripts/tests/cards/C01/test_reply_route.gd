# C01 #42（GPT 复审 P1）：共享根 dialog 的回话只由根转给 play.on_reply 一次。
# 真 CardGameRoot + 真 C04 柜台 / 真 C05 条子面板 / 真 C03、C11 面板，不用替身。
# 一次按钮回话、一次数字键回话 → 恰好一条 counter.offer / card.choose。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const C04 = preload("res://scripts/tests/cards/C04/support.gd")
const C05 = preload("res://scripts/tests/cards/C05/support.gd")
const S = preload("res://scripts/tests/cards/C01/support.gd")


func _initialize() -> void:
	var t := T.new(self, "C01_reply_route")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	await _counter_button_once(t)
	await _counter_key_once(t)
	await _demand_button_once(t)
	await _other_stage_consumers(t)


func _offers(mock: MockCardEngine) -> int:
	var n := 0
	for row in mock.sent:
		if str(row[0]) == "counter.offer":
			n += 1
	return n


func _direct_links(game: CardGameRoot, panel: Object) -> int:
	var n := 0
	for c in game.dialog.reply_chosen.get_connections():
		var cb: Callable = c["callable"]
		if cb.get_object() == panel:
			n += 1
	return n


func _root_links(game: CardGameRoot) -> int:
	var n := 0
	for c in game.dialog.reply_chosen.get_connections():
		var cb: Callable = c["callable"]
		if cb.get_object() == game:
			n += 1
	return n


func _reply_index(game: CardGameRoot, reply_id: String) -> int:
	var buttons: Array = []
	game._collect_reply_buttons(game.dialog, buttons)
	for i in buttons.size():
		var b: Button = buttons[i]
		if b.has_meta("reply_id") and str(b.get_meta("reply_id")) == reply_id:
			return i
	return -1


func _counter_button_once(t) -> void:
	var ctx: Dictionary = C04.boot(self, "counter_then_leave")
	await t.frames(1)
	var game: CardGameRoot = ctx.game
	var panel := C04.play(ctx, "c0002")
	await t.frames(2)
	t.ok(panel != null, "C04 counter opened on the real root")
	if panel == null:
		C04.free_ctx(ctx)
		await t.frames(2)
		return
	t.ok(panel.dialog == game.dialog, "C04 uses the shared root dialog")
	t.eq(_root_links(game), 1, "root forwards reply_chosen once")
	t.eq(_direct_links(game, panel), 0, "C04 does not also subscribe to the shared dialog")
	var before := _offers(ctx.mock)
	var fair := C04.button(panel, "TierFair")
	t.ok(fair != null, "fair reply button present")
	if fair != null:
		fair.pressed.emit()
	await t.frames(2)
	t.eq(_offers(ctx.mock) - before, 1, "one fair button press → exactly one counter.offer")
	# 夹具回 counter 后仍在 talk，第二次 _show_tiers() 也通过：双发时这里会是 2。
	t.eq(str(panel.get("_phase")), "talk", "after one offer the guest counters (still talk)")
	C04.free_ctx(ctx)
	await t.frames(2)


func _counter_key_once(t) -> void:
	var ctx: Dictionary = C04.boot(self, "counter_then_leave")
	await t.frames(1)
	var game: CardGameRoot = ctx.game
	var panel := C04.play(ctx, "c0002")
	await t.frames(2)
	var idx := _reply_index(game, "tier:fair")
	t.ok(idx >= 0 and idx < 9, "fair reply has a digit key (index %d)" % idx)
	var before := _offers(ctx.mock)
	if idx >= 0 and idx < 9:
		S.press(game, (KEY_1 + idx) as Key)
	await t.frames(2)
	t.eq(_offers(ctx.mock) - before, 1, "one digit key → exactly one counter.offer")
	if panel != null:
		t.eq(_direct_links(game, panel), 0, "C04 still not directly subscribed after a reply")
	C04.free_ctx(ctx)
	await t.frames(2)


func _demand_button_once(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game := C05.boot(self, bus, "money.json")
	await t.frames(1)
	var panel := game.host.open_panel(&"demand", {"uid": "m_pay"}) as CardDemandPanel
	await t.frames(1)
	t.ok(panel != null, "C05 demand opened on the real root with uid m_pay")
	if panel != null:
		t.ok(panel.dialog == game.dialog, "C05 uses the shared root dialog")
		t.eq(_direct_links(game, panel), 0, "C05 does not subscribe to the shared dialog")
		C05.skip_dialog(panel)
		await t.frames(1)
		var mock: MockCardEngine = game.engine
		var before := 0
		for row in mock.sent:
			if str(row[0]) == "card.choose":
				before += 1
		var btn := C05.reply_button(panel, "c05.mode.pay")
		t.ok(btn != null, "C05 pay reply present")
		if btn != null:
			btn.pressed.emit()
		await t.frames(1)
		var after := 0
		for row in mock.sent:
			if str(row[0]) == "card.choose" and str((row[1] as Dictionary).get("choice", "")) == "pay":
				after += 1
		t.eq(after - before, 1, "one pay reply → exactly one card.choose")
	while game.host.top_panel() != null:
		game.host.close_top()
	await t.frames(1)
	game.queue_free()
	bus.queue_free()
	await t.frames(2)


func _other_stage_consumers(t) -> void:
	# C03 条子格、C11 牢房也拿共享 dialog：同样只由根转发，自身不再直连。
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game := S.boot(self, bus, "day_full")
	await t.frames(2)
	for kind in [&"slots", &"prison"]:
		var panel := game.host.open_panel(kind, {}) as CardStagePanel
		await t.frames(1)
		t.ok(panel != null, String(kind) + " stage panel opened")
		if panel != null:
			t.ok(panel.dialog == game.dialog, String(kind) + " uses the shared root dialog")
			t.eq(_direct_links(game, panel), 0, String(kind) + " does not subscribe to the shared dialog")
		while game.host.top_panel() != null:
			game.host.close_top()
		await t.frames(1)
	t.eq(_root_links(game), 1, "root is the single reply forwarder")
	game.queue_free()
	CardAnchors.clear()
	bus.queue_free()
	await t.frames(2)
