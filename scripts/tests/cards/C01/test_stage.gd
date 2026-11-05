# C01 场景层：背景、查封下雨、热点、拖放、站位、快动画、夜里的染色。
# 告示热点：真引擎的 notice.news 是 {key, args}，Mock 是裸键；两种都按 CardText 说，不把字典原样印出来（#194）。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C01/support.gd")


func _initialize() -> void:
	var t := T.new(self, "C01_stage")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	await _backgrounds(t, bus)
	await _effects(t, bus)
	await _hotspots(t, bus)
	await _notice_news(t, bus)
	await _drop_and_cast(t, bus)
	bus.queue_free()
	await t.frames(1)


func _backgrounds(t, bus: CardEventBus) -> void:
	var dusk := S.boot(self, bus, "res://scripts/tests/cards/C01/fixtures/dusk.json")
	await t.frames(2)
	t.eq(dusk.stage.background_id(), "bg.counter.dusk", "dusk background")
	dusk.queue_free()
	CardAnchors.clear()
	await t.frames(1)
	var game := S.boot(self, bus, "day_full")
	await t.frames(2)
	game.stage.fast = true
	game.stage.refresh(_view("street", "day", false))
	t.eq(game.stage.background_id(), "bg.street", "street background")
	game.stage.refresh(_view("prison", "night", false))
	t.eq(game.stage.background_id(), "bg.prison", "prison background")
	game.stage.refresh(_view("counter", "day", false))
	t.eq(game.stage.background_id(), "bg.counter.day", "day background")
	game.queue_free()
	CardAnchors.clear()
	await t.frames(1)


func _effects(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "res://scripts/tests/cards/C01/fixtures/sealed_rain.json")
	await t.frames(2)
	t.ok(game.stage.effect_on("Rain"), "rain is on")
	t.ok(game.stage.effect_on("Seal"), "seal is on")
	t.ok(game.stage.effect_on("Shadow"), "heat shadow is on")
	game.queue_free()
	CardAnchors.clear()
	await t.frames(1)


func _hotspots(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "day_full")
	await t.frames(2)
	while game.host.top_panel() != null:
		game.host.close_panel(game.host.top_panel())
	await t.frames(1)
	for id in CardIds.HOTSPOTS:
		var button := game.stage.get_node(str(id)) as BaseButton
		button.pressed.emit()
		await t.frames(1)
		if id == &"notice":
			t.ok(game.dialog.visible, "notice opens the dialog")
			game.dialog.clear()
		elif id == &"lamp":
			t.ok(game.host.top_panel() == null, "lamp does not open a panel")
		elif id == &"magnifier":
			t.ok(game.host.top_panel() == null, "magnifier without a play does nothing")
		else:
			var route: Array = CardIds.HOTSPOT_PANELS[id]
			t.eq(game.host.top_kind(), route[0], "hotspot %s" % id)
			game.host.close_panel(game.host.top_panel())
			await t.frames(1)
	game.queue_free()
	CardAnchors.clear()
	await t.frames(1)


func _notice_news(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "day_full")
	await t.frames(2)
	while game.host.top_panel() != null:
		game.host.close_panel(game.host.top_panel())
	game.dialog.clear()
	await t.frames(1)
	var mock := game.engine as MockCardEngine
	mock._view["notice"]["news"] = [{"key": "g02.notice.rain", "args": {}},
		{"key": "g04.month.expenses", "args": {"money": 120}}, "g02.notice.market_day"]
	# 一句一句推（chars_per_sec 为 0 时对话框直接跳到最后一句）。
	game.dialog.chars_per_sec = 40
	(game.stage.get_node("notice") as BaseButton).pressed.emit()
	await t.frames(1)
	t.ok(game.dialog.visible, "real-engine notice rows open the dialog")
	var said: Array = []
	for i in range(8):
		said.append_array(_texts(game.dialog))
		if game.dialog.is_idle():
			break
		game._advance_dialog()
		await t.frames(1)
	var want: Array = [CardText.ui("g02.notice.rain"), CardText.ui("g04.month.expenses", {"money": 120}),
		CardText.ui("g02.notice.market_day")]
	for line in want:
		t.ok(said.has(line), "notice says " + line)
	for txt in said:
		t.ok(not str(txt).contains("{\"key\"") and not str(txt).contains("\"args\""), "no raw notice dictionary: " + str(txt))
	t.eq(t.all_text_from_cardtext(game.dialog).size(), 0, "notice text is CardText")
	game.dialog.clear()
	game.queue_free()
	CardAnchors.clear()
	await t.frames(1)


func _texts(node: Node) -> Array:
	var out: Array = []
	if node is Label and (node as Label).text != "":
		out.append((node as Label).text)
	elif node is RichTextLabel and (node as RichTextLabel).get_parsed_text() != "":
		out.append((node as RichTextLabel).get_parsed_text())
	for child in node.get_children():
		out.append_array(_texts(child))
	return out


func _drop_and_cast(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "day_full")
	await t.frames(2)
	while game.host.top_panel() != null:
		game.host.close_panel(game.host.top_panel())
	await t.frames(1)
	var uid := str(game.engine.view()["hand"][0].get("uid", ""))
	var panel := StringName(str(game.engine.query(&"card", {"uid": uid}).get("panel", "none")))
	game.stage._drop_data(Vector2(400, 200), {"kind": "card", "zone": "self", "uid": uid})
	await t.frames(1)
	t.ok(game.host.top_panel() == null, "a self drop does not open a panel")
	game.stage._drop_data(Vector2(400, 200), {"kind": "card", "zone": "hand", "uid": uid})
	await t.frames(1)
	t.eq(game.host.top_kind(), panel, "a hand drop opens the card")
	game.host.close_panel(game.host.top_panel())
	t.eq(game.stage.spot_rect(&"customer"), CardLayout.spot(&"customer"), "customer spot")
	game.stage.fast = true
	var walkers := game.stage.get_node("Effects").get_node_or_null("Walkers")
	t.ok(walkers != null and walkers.get_child_count() >= 1, "day counter spawns doorway walker")
	if walkers != null and walkers.get_child_count() >= 1:
		var walker := walkers.get_child(0) as TextureRect
		t.ok(walker.texture is AtlasTexture, "walker uses AtlasTexture frame cut")
		if walker.texture is AtlasTexture:
			t.eq((walker.texture as AtlasTexture).region, Rect2(0, 0, 16, 32), "walker frame region is 16x32")
	game.stage.play({"set": "counter", "cast": [{"who": "ex_patrol", "at": "door", "look": "stand"}]})
	var door_actor := game.stage.get_node("Cast").get_child(0) as TextureRect
	t.ok(door_actor.texture is AtlasTexture, "door customer uses AtlasTexture frame cut")
	if door_actor.texture is AtlasTexture:
		t.eq((door_actor.texture as AtlasTexture).region, Rect2(0, 0, 16, 32), "door customer frame region is 16x32")
	game.stage.refresh(_view("counter", "night", false))
	game.stage.play({"set": "counter", "cast": [{"who": "brother", "at": "customer", "look": "stand"}]})
	var actor := game.stage.get_node("Cast").get_child(0) as CanvasItem
	t.eq(actor.position, CardLayout.spot(&"customer").position, "fast enter snaps")
	t.eq(actor.modulate, CardTheme.color(&"night_tint"), "night tint")
	game.queue_free()
	CardAnchors.clear()
	await t.frames(1)


func _view(set_name: String, time: String, sealed: bool) -> Dictionary:
	return {"stage": {"set": set_name, "time": time, "sealed": sealed}, "notice": {}, "demands": [], "heat_tier": 0}
