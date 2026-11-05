# C01 指引宿主：layer 100、鼠标穿透、点手牌仍能按到牌、本任务的步骤会亮。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C01/support.gd")
const STEPS_PATH := "res://scripts/tests/cards/C01/guide_steps.json"
const FIX := "res://scripts/tests/cards/C01/fixtures/guide_day.json"


func _initialize() -> void:
	var test_name := "C01_guide_host"
	var steps_mode := "file"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--name="):
			test_name = a.substr(7)
		elif a.begins_with("--steps="):
			steps_mode = a.substr(8)
	var t := T.new(self, test_name)
	t.run_async(_body.bind(t, steps_mode))


func _body(t, steps_mode: String) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	await _click_through(t, bus)
	var game := S.boot(self, bus, FIX)
	await t.frames(2)
	var layer := game.guide.get_parent()
	t.ok(layer is CanvasLayer, "guide parent is a CanvasLayer")
	t.eq((layer as CanvasLayer).layer, 100, "guide layer is 100")
	_ignore(t, game.guide)
	t.ok(not game.guide.is_enabled(), "cards-mock without --guide is off")
	game.guide.force(true)
	game.guide.skip_fades = true
	var data: Dictionary = game.engine.query(&"guide_data") if steps_mode == "k16" else CardDB.read_json(STEPS_PATH)
	game.guide.load_steps(data)
	var steps: Array = data.get("steps", [])
	steps.sort_custom(_by_priority)
	t.ok(not steps.is_empty(), "steps loaded")
	_emit_firsts(bus, steps)
	for step in steps:
		await _prove(t, game, bus, str(step.get("id", "")))
	game.queue_free()
	bus.queue_free()
	await t.frames(1)


func _click_through(t, bus: CardEventBus) -> void:
	var game := S.boot(self, bus, "day_full")
	await t.frames(2)
	game.guide.force(true)
	game.guide.skip_fades = true
	game.guide.load_steps({
		"settings": {"gap_ms": 0, "default_seconds": 30},
		"steps": [{
			"id": "gd.probe.hand",
			"teaches": [],
			"trigger": {"phase": "day"},
			"teacher": "brother",
			"anchor": "a.hand",
			"done_when": ["ui:hand_selected"],
			"priority": 100,
			"max_shows": 2,
			"seconds": 30,
			"brief": "probe click through the guide",
		}],
	})
	var hit := {"ok": false}
	# C02 手牌扇：点的是 Slot，Face 是 IGNORE，不发 CardWidget.pressed；听 hand_selected。
	bus.ui_event.connect(func(ev_name: StringName, args: Dictionary) -> void:
		if ev_name == &"hand_selected":
			hit["ok"] = true
	)
	var widget := _first_card(game.hand)
	t.ok(widget != null, "day_full has a card widget")
	game.guide.evaluate_now()
	t.eq(game.guide.active_step(), "gd.probe.hand", "probe step is lit")
	if widget != null:
		# 扇面有旋转，AABB 中心可能不在可点多边形上；点可见区靠上、偏左。
		var rect := widget.get_global_rect()
		var y := minf(rect.position.y + 24.0, 700.0)
		S.click(game, Vector2(rect.position.x + 8.0, y))
	await t.frames(2)
	t.ok(bool(hit["ok"]), "click at the card still presses it")
	game.queue_free()
	CardAnchors.clear()
	await t.frames(1)


func _prove(t, game, bus: CardEventBus, id: String) -> void:
	game.guide.evaluate_now()
	t.eq(game.guide.active_step(), id, "step " + id)
	bus.ui_event.emit(&"hand_selected", {"uid": "c0101"})
	await t.frames(1)
	t.eq(game.guide.active_step(), "", id + " cleared")
	_done_sent(t, game.engine, id)


func _by_priority(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("priority", 0)) > int(b.get("priority", 0))


func _emit_firsts(bus: CardEventBus, steps: Array) -> void:
	var seen := {}
	for step in steps:
		var first := str(step.get("trigger", {}).get("first", ""))
		if first != "" and not seen.has(first):
			seen[first] = true
			bus.first_time.emit(StringName(first), {})


func _done_sent(t, mock: MockCardEngine, id: String) -> void:
	var ok := false
	for row in mock.sent:
		if str(row[0]) == "ui.guide" and str(row[1].get("step", "")) == id and str(row[1].get("status", "")) == "done":
			ok = true
	t.ok(ok, "ui.guide done for " + id)


func _first_card(node: Node) -> CardWidget:
	if node is CardWidget:
		var widget := node as CardWidget
		# 跳过预览牌（passive / 不可见 / 无 uid）。
		if widget.visible and widget.is_visible_in_tree() and widget.get_uid() != "":
			return widget
	for child in node.get_children():
		var found := _first_card(child)
		if found != null:
			return found
	return null


## Contract 7.10.7 (10-22 prototype note): only the bubble's two buttons ("got it", "turn the guide off")
## take the mouse; every other node of the guide layer lets clicks through.
func _ignore(t, n: Node) -> void:
	if n is BaseButton and n.get_parent() != null and n.get_parent().name == "Bubble":
		t.ok(n.name in ["Ok", "Off"], "only the bubble's own buttons: " + str(n.name))
		t.ok((n as Control).focus_mode == Control.FOCUS_NONE, "bubble button never takes key focus: " + str(n.name))
	elif n is Control:
		t.ok((n as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "ignore " + str(n.name))
	for c in n.get_children():
		_ignore(t, c)
