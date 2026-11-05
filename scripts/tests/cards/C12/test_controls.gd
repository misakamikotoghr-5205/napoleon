# Panel size, words from CardText, no "%", frame cost, tool events, ink stops pins, Esc aborts, and the
# keyboard plays a whole round (contract 8.2). The old keyboard round drew circles; now arrows move the
# cursor pixel, Enter opens the call, 1 / 2 call it, 0 takes it away (the same ops as the mouse; the
# mouse-only round is test_mouse.gd).
# Owner C12. Contract: docs/cards/CARDS_INTERFACES.md 8.2, 12.2, 12.4.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Lib = preload("res://scripts/tests/cards/C12/c12_lib.gd")


func _initialize() -> void:
	var t := T.new(self, "C12_controls")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	t.ok(mock.db != null, "text db")
	var spy = t.spy(bus)
	await t.frames(1)
	var params: Dictionary = Lib.fixture("hairpin3")
	var game := Lib.open_game(self, params)
	game.bind_bus(bus)
	await t.frames(2)
	var board := game.get_node("Board") as Control
	t.ok(board.size.x > 0 and board.size.x <= 1100 and board.size.y > 0 and board.size.y <= 640, "panel size")
	t.ok(Rect2(0, 0, 1280, 720).encloses(board.get_global_rect()), "panel on screen")
	t.eq(t.all_text_from_cardtext(game).size(), 0, "labels from CardText")
	t.ok(_no_percent(game), "no percent sign")
	for n in ["Item", "Atlas", "EyeButton", "LensButton", "Done", "Legend", "PinList"]:
		var c := board.get_node(n) as Control
		t.ok(board.get_rect().encloses(c.get_global_rect()), n + " inside the panel")
	_no_overlap(t, board)
	await t.frames(8)
	board.queue_redraw()
	var samples: Array = []
	var worst := 0
	for _i in 60:
		var started := Time.get_ticks_usec()
		await t.frames(1)
		var dt := Time.get_ticks_usec() - started
		samples.append(dt)
		worst = maxi(worst, dt)
	samples.sort()
	print("PERF max_frame_us %d med %d" % [worst, samples[30]])
	var cpu_worst := 0
	for _i in 60:
		var started2 := Time.get_ticks_usec()
		board.notification(Node.NOTIFICATION_PROCESS)
		cpu_worst = maxi(cpu_worst, Time.get_ticks_usec() - started2)
	print("PERF cpu_us %d" % cpu_worst)
	t.ok(cpu_worst <= 4000, "frame cpu")
	spy.clear()
	t.ok(game.apply_op(["atlas"]), "book")
	t.ok(game.apply_op(["tool", "lens"]), "lens")
	t.ok(game.apply_op(["tool", "eye"]), "eye")
	var tools: Array = []
	for row in spy.ui_events():
		t.eq(str(row[0]), "mg_tool", "event name")
		t.eq(str(row[1].get("kind", "")), "spot", "event kind")
		tools.append(str(row[1].get("tool", "")))
	t.eq(tools, ["atlas", "lens", "eye"], "tool events")
	var played: Array = [null]
	game.finished.connect(func(result: Dictionary) -> void: played[0] = result)
	game.apply_op(["pin", 38, 24, 1])
	game.apply_op(["done"])
	t.ok(played[0] != null, "finished")
	t.eq(bool(played[0].get("aborted", true)), false, "not aborted")
	t.ok((played[0].get("observations", []) as Array).size() > 0, "a pin was recorded")
	game.queue_free()
	var drained: Dictionary = Lib.run(self, params, _drain_ink)
	t.eq(int(drained.get("measures", {}).get("ink_used", -1)), 4, "ink stops pins")
	t.eq((drained.get("measures", {}).get("spots", []) as Array).size(), 4, "four pins for four ink")
	var aborted: Dictionary = Lib.run(self, params, func(g: CardSpotGame) -> void:
		g.apply_op(["atlas"])
		g.apply_op(["pin", 38, 24, 1])
		_esc(g))
	t.eq(bool(aborted.get("aborted", false)), true, "esc aborts")
	t.eq((aborted.get("observations", ["x"]) as Array).size(), 0, "esc has no observations")
	t.eq(int(aborted.get("minutes", -1)), 3, "esc keeps the minutes spent")
	var keyed: Dictionary = Lib.run(self, params, func(g: CardSpotGame) -> void:
		_keys(g, [KEY_A, KEY_L])
		for _i in 6:
			_keys(g, [KEY_RIGHT])
		for _i in 2:
			_keys(g, [KEY_UP], true)
		_keys(g, [KEY_ENTER])
		t.ok(Lib.board(g).bubble_open(), "Enter opens the call at the cursor")
		_keys(g, [KEY_1])
		t.eq(g.pins(), [[38, 24, 1]], "1 calls it old wear")
		_keys(g, [KEY_2])
		t.eq(g.pins(), [[38, 24, 2]], "2 on a pin changes its call")
		for _i in 3:
			_keys(g, [KEY_LEFT], true)
		_keys(g, [KEY_DOWN, KEY_DOWN])
		_keys(g, [KEY_2])
		t.eq(g.pins(), [[38, 24, 2], [26, 26, 2]], "2 off a pin pins it at the cursor")
		_keys(g, [KEY_ENTER, KEY_0])
		t.eq(g.pins(), [[38, 24, 2]], "Enter then 0 takes it away")
		_keys(g, [KEY_F1])
		t.eq(g.is_done(), false, "F1 is left for help")
		_keys(g, [KEY_F]))
	t.ok(keyed != null, "keyboard plays a whole round")
	if keyed != null:
		t.eq(keyed.get("measures", {}).get("spots"), [[38, 24, 2]], "keyboard spots")
		t.eq(bool(keyed.get("measures", {}).get("lens", false)), true, "L took the lens")
		t.eq(bool(keyed.get("measures", {}).get("atlas", false)), true, "A opened the book")
	bus.queue_free()
	await t.frames(3)


func _keys(game: CardSpotGame, codes: Array, shift: bool = false) -> void:
	for code in codes:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.pressed = true
		ev.shift_pressed = shift
		game._unhandled_input(ev)


func _drain_ink(game: CardSpotGame) -> void:
	for i in 6:
		game.apply_op(["pin", 10 + i, 10, 1])
	game.apply_op(["done"])


func _esc(game: CardSpotGame) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_ESCAPE
	game._unhandled_input(ev)


## Buttons and wells do not overlap each other (the host's abort spot is checked in C12_host_abort).
func _no_overlap(t, board: Control) -> void:
	var rects: Array = []
	for n in ["Item", "Atlas", "EyeButton", "LensButton", "BlinkButton", "Ink", "Rule", "Legend", "PinList", "Done"]:
		var c := board.get_node(n) as Control
		rects.append([n, Rect2(c.position, c.size)])
	rects.append(["AbortSpot", board.ABORT_SPOT])
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			var a: Rect2 = rects[i][1]
			var b: Rect2 = rects[j][1]
			t.ok(not a.intersects(b), "%s and %s do not overlap" % [rects[i][0], rects[j][0]])


func _no_percent(node: Node) -> bool:
	var txt := ""
	if node is Label:
		txt = (node as Label).text
	elif node is Button:
		txt = (node as Button).text
	elif node is RichTextLabel:
		txt = (node as RichTextLabel).get_parsed_text()
	if txt.contains("%"):
		return false
	for c in node.get_children():
		if not _no_percent(c):
			return false
	return true
