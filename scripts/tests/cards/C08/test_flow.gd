# C08: Space, Enter, and 1 reach the morning of day 2, from night and from an untouched day.
# Owner C08. Contract 1.3.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Support = preload("res://scripts/tests/cards/C08/support.gd")


func _initialize() -> void:
	var t := T.new(self, "C08_flow")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	await _from_night(t)
	await _from_untouched_day(t)


func _from_night(t) -> void:
	var game := _boot()
	var bus: CardEventBus = game[0]
	var root_node: CardGameRoot = game[1]
	await t.frames(2)
	var steps := 0
	while steps < 400:
		var view: Dictionary = root_node.engine.view()
		var day := int(view.get("date", {}).get("stage_day", 0))
		if str(view.get("phase", "")) == "night" and day == 1 and root_node.host.top_kind() == &"night":
			break
		root_node.autoplay_step()
		await t.frames(1)
		steps += 1
	var at_night: Dictionary = root_node.engine.view()
	t.eq(str(at_night.get("phase", "")), "night", "reached night in %d steps" % steps)
	t.eq(int(at_night.get("date", {}).get("stage_day", 0)), 1, "still day 1")
	t.eq(root_node.host.top_kind(), &"night", "night panel is open")
	await _keys_to_morning(t, root_node, "space path")
	root_node.queue_free()
	bus.queue_free()
	await t.frames(2)


func _from_untouched_day(t) -> void:
	var game := _boot()
	var bus: CardEventBus = game[0]
	var root_node: CardGameRoot = game[1]
	await t.frames(2)
	var steps := 0
	while steps < 200:
		var view: Dictionary = root_node.engine.view()
		var day := int(view.get("date", {}).get("stage_day", 0))
		if str(view.get("phase", "")) == "day" and day == 1 and root_node.host.top_panel() == null:
			break
		root_node.autoplay_step()
		await t.frames(1)
		steps += 1
	var at_day: Dictionary = root_node.engine.view()
	t.eq(str(at_day.get("phase", "")), "day", "reached day without playing cards (%d)" % steps)
	t.eq(int(at_day.get("date", {}).get("stage_day", 0)), 1, "untouched day is day 1")
	t.eq(root_node.host.top_panel(), null, "the table is clear")
	var close: Button = Support.button_with(root_node, CardText.ui("w0.btn.close_day"))
	if close == null:
		close = root_node.get("_end")  # C01 #42 起收工键改由 a.btn.close_day 大按钮承担
	t.ok(close != null, "close-day button")
	close.pressed.emit()
	await t.frames(3)
	t.eq(root_node.host.top_kind(), &"end_day", "close day opens the list")
	await Support.tap(self, KEY_ENTER)
	await t.frames(2)
	t.eq(root_node.host.top_kind(), &"night", "confirm opens the night")
	await _keys_to_morning(t, root_node, "untouched day")
	root_node.queue_free()
	bus.queue_free()
	await t.frames(2)


func _keys_to_morning(t, root_node: CardGameRoot, label: String) -> void:
	var mock := root_node.engine as MockCardEngine
	var mark := mock.sent.size()
	var codes: Array = [KEY_1, KEY_SPACE, KEY_ENTER]
	var guard := 0
	while guard < 24:
		var now: Dictionary = root_node.engine.view()
		if str(now.get("phase", "")) == "morning" and int(now.get("date", {}).get("stage_day", 0)) == 2:
			break
		await Support.tap(self, codes[guard % codes.size()])
		guard += 1
	var done: Dictionary = root_node.engine.view()
	t.eq(str(done.get("phase", "")), "morning", label + " reached morning (keys=%d)" % guard)
	t.eq(int(done.get("date", {}).get("stage_day", 0)), 2, label + " morning of day 2")
	var night_n := 0
	var settle_n := 0
	for i in range(mark, mock.sent.size()):
		var row: Array = mock.sent[i]
		if str(row[0]) == "night.choose":
			night_n += 1
			t.eq(row[1], {"def": "nt.tidy"}, label + " picks the first night card")
		elif str(row[0]) == "settle.next":
			settle_n += 1
	t.eq(night_n, 1, label + " one night.choose")
	t.eq(settle_n, 1, label + " one settle.next")


func _boot() -> Array:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true, "bus": bus, "seed": 7, "skip_title": true, "guide": "off"})
	root.add_child(game)
	return [bus, game]
