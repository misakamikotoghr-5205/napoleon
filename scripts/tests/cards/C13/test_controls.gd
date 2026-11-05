# 面板和规矩：吹次用完只能说和交；钟点 = (吹 + 碰) × minutes_per_step，封顶 max_minutes；每个动作发 mg_tool；
# 面板 1000x640 @ (140, 40)（DESIGN §5.9）、银元整数倍放大、最近邻；界面字都来自 CardText，没有数字和 %；
# 一枚和一摞的样子（三个选项 / 每枚一个小牌）；余音框：甲、乙各钉一行，中间 ghosts 行放客人的；面板上那句话一行放得下。
# 键盘能玩完一局（合同 §8.2）：← / → 挪“手”、Space / Enter 吹、C 碰、单枚 1 / 2 / 3 说、一摞数字标记、F 交，
# 走的是和鼠标同一批 op；外面（手牌）有焦点时方向键、空格也归小游戏；连按（echo）和 Ctrl 组合键不算。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C13/harness.gd")


func _initialize() -> void:
	var t := T.new(self, H.arg("name", "C13_controls"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	CardText.setup(CardDB.load_all(CardDB.DEFAULT_ROOT, {}))
	var tools: Array = []
	bus.ui_event.connect(func(n: StringName, a: Dictionary) -> void:
		if n == &"mg_tool":
			tools.append(str(a.get("tool", "")))
			t.eq(str(a.get("kind", "")), "coin_ring", "mg_tool kind")
	)
	for name in ["v2_good", "v2_stack", "good"]:
		var g := H.open(self, H.fixture(name), bus)
		await t.frames(1)
		_surface(t, g, H.fixture(name), name)
		await H.drop(self, [g])
	var g := H.open(self, H.fixture("v2_stack"), bus)
	await t.frames(1)
	tools.clear()
	g.apply_op(["blow", -1])
	g.apply_op(["clink", 0, 1])
	g.apply_op(["mark", 0, 1])
	g.apply_op(["done"])
	t.eq(tools, ["blow", "clink", "mark"], "each action sends its mg_tool")
	await H.drop(self, [g, bus])
	mock = null
	await _tries(t)
	await _minutes(t)
	await _ghosts(t)
	await _keys(t)


func _surface(t, g: CardCoinRingGame, fix: Dictionary, name: String) -> void:
	t.eq(t.all_text_from_cardtext(g), PackedStringArray(), name + ": text comes from CardText")
	var digits := _digit_text(g)
	t.eq(digits.size(), 0, name + ": no digits or percent: %s" % " | ".join(digits))
	t.eq(g._panel.position, CardCoinRingGame.PANEL_POS, name + ": panel position")
	t.eq(g._panel.size, CardCoinRingGame.PANEL_SIZE, name + ": panel size")
	var arts: Array = []
	for f in g._coin_faces + g._sample_faces:
		arts.append(f.art())
	var base := CardArt.base_size(str(fix["art"]))
	for art in arts:
		var a := art as TextureRect
		t.eq(a.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, name + ": nearest")
		var b := base if g._coin_faces.has(a.get_parent()) else CardArt.base_size(CardCoinRingGame.SAMPLE_ART)
		t.ok(b.x > 0 and int(a.size.x) % b.x == 0 and int(a.size.y) % b.y == 0, name + ": integer scale %s" % a.size)
		t.eq(int(a.size.x) / b.x, int(a.size.y) / b.y, name + ": uniform scale")
	var n := (fix["coins"] as Array).size()
	t.eq(g._coin_faces.size(), maxi(n, 1), name + ": one face per coin")
	if n >= 2:
		t.eq(g._chips.size(), n, name + ": one tag per coin")
		t.eq(g._call_btns.size(), 0, name + ": no single calls for a roll")
		t.eq(int((g._coin_faces[0] as Control).size.x), 128 + 12, name + ": roll coins at x2")
	else:
		t.eq(g._call_btns.size(), 3, name + ": three calls for one coin")
		t.eq(g._chips.size(), 0, name + ": no tags for one coin")
		t.eq(int((g._coin_faces[0] as Control).size.x), 192 + 12, name + ": one coin at x3")
	var note := g._panel.get_node_or_null("Note") as Label
	t.ok(note != null, name + ": the note line is there")
	if note != null:
		var font := note.get_theme_font("font")
		var w := font.get_string_size(note.text, HORIZONTAL_ALIGNMENT_LEFT, -1, note.get_theme_font_size("font_size")).x
		t.ok(w <= note.size.x, name + ": the note fits its line (%d <= %d)" % [int(w), int(note.size.x)])
	for id in ["a.mg.coin_ring.main", "a.mg.coin_ring.blow", "a.mg.coin_ring.ear"]:
		t.ok(t.anchor_ok(StringName(id)), name + ": anchor %s on screen" % id)
	var screen := Rect2(0, 0, 1280, 720)
	for c in g._call_btns + g._chips + [g._done_btn] + g._coin_faces + g._sample_faces:
		t.ok(g._panel.get_global_rect().encloses((c as Control).get_global_rect()), name + ": %s inside the frame" % c.name)
		t.ok(screen.encloses((c as Control).get_global_rect()), name + ": %s on screen" % c.name)


func _tries(t) -> void:
	var g_fix := H.fixture("one_try")
	var out: Dictionary = await H.run_ops(self, g_fix, [["blow", 0], ["blow", -1], ["clink", 0, 0], ["call", 1], ["done"]])
	t.eq(out["accepted"], [true, false, false, true, true], "after the only try, only judging and done remain")
	t.eq(out["result"]["minutes"], 1, "one blow, one minute")
	var stack: Dictionary = await H.run_ops(self, H.fixture("stack"), [["blow", 0], ["blow", 1], ["clink", 1, 2], ["blow", 2], ["blow", 0], ["done"]])
	t.eq(stack["accepted"], [true, true, true, true, false, true], "four tries: three blows and a clink")


func _minutes(t) -> void:
	var fix := H.fixture("v2_stack")
	fix["minutes_per_step"] = 2
	fix["max_minutes"] = 7
	var ops: Array = [["blow", -1], ["clink", 0, 1], ["mark", 0, 1], ["done"]]
	t.eq((await H.run_ops(self, fix, ops))["result"]["minutes"], 4, "blow and clink cost a step each, marks cost nothing")
	var many: Array = [["blow", -1], ["blow", -2], ["blow", 0], ["blow", 1], ["blow", 2], ["done"]]
	t.eq((await H.run_ops(self, fix, many))["result"]["minutes"], 7, "capped at max_minutes")


## With ghosts the two samples keep a row each once blown (甲 on top, 乙 at the bottom) and the latest coin lines
## take the ghosts rows between them (blind re-check 2: blowing the coin no longer pushes 乙 out). With no ghosts it
## is one row with the latest line.
func _ghosts(t) -> void:
	var want := {0: [-1], 1: [-1, 0, -2], 2: [-1, 0, -2]}
	var rows := {0: 1, 1: 3, 2: 4}
	for ghosts in [0, 1, 2]:
		var fix := H.fixture("v2_good")
		fix["ghosts"] = ghosts
		var bus := CardEventBus.new()
		root.add_child(bus)
		var g := H.open(self, fix, bus)
		for who in [-1, -2, 0, -1]:
			g.apply_op(["blow", who])
		t.eq(g._wave.cap, rows[ghosts], "ghosts %d: %d rows" % [ghosts, rows[ghosts]])
		t.eq(g._wave.held(), want[ghosts], "ghosts %d: silver pinned on top, dull at the bottom, the coin between" % ghosts)
		await H.drop(self, [g, bus])


## Keyboard only, sent through the viewport like real keys.
func _keys(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	# A focused control outside the game (a hand card under the overlay) must not take the keys.
	var outside := Button.new()
	outside.focus_mode = Control.FOCUS_ALL
	root.add_child(outside)
	var g := H.open(self, H.fixture("v2_good"), bus)
	var box: Array = [null]
	g.finished.connect(func(r: Dictionary) -> void: box[0] = r)
	await t.frames(1)
	outside.grab_focus()
	t.eq(_hand(g), [], "no keyboard hand drawn before a key is pressed")
	H.key(g, KEY_RIGHT)
	t.eq(_hand(g), [g._sample_faces[0]], "the first arrow shows the hand on the silver sample")
	H.key(g, KEY_SPACE)
	H.key(g, KEY_RIGHT)
	H.key(g, KEY_ENTER)
	H.key(g, KEY_RIGHT)
	t.eq(_hand(g), [g._coin_faces[0]], "the arrow moves the hand on to the customer's coin")
	H.key(g, KEY_KP_ENTER)
	H.key(g, KEY_RIGHT)
	t.eq(_hand(g), [g._sample_faces[0]], "the hand wraps round")
	H.key(g, KEY_LEFT)
	t.eq(_hand(g), [g._coin_faces[0]], "left goes back")
	H.key(g, KEY_1)
	H.key(g, KEY_3)
	H.key(g, KEY_2)
	H.key(g, KEY_4)
	H.key(g, KEY_C)
	t.eq(g.ops_log(), [["blow", -1], ["blow", -2], ["blow", 0], ["call", 1], ["call", 3], ["call", 2]],
		"keys go through the same ops as the mouse")
	t.ok(outside.has_focus(), "the focus outside never moved")
	t.eq((g._call_btns[1] as Button).get_theme_color("font_color"), CardTheme.color(&"gold_hi"), "the keyed call is in the player's pen")
	H.key(g, KEY_F)
	t.ok(box[0] != null, "F hands it back")
	var r: Dictionary = box[0] if box[0] != null else {}
	t.eq(r.get("observations", []), ["obs.coin_ring.like_dull_sample"], "the keyed call is the observation")
	t.eq(r.get("quality_permille", -1), 1000, "both samples, the coin, and compared")
	H.key(g, KEY_SPACE)
	t.eq(g.ops_log().size(), 7, "keys after done do nothing")
	await H.drop(self, [g, bus, outside])
	bus = CardEventBus.new()
	root.add_child(bus)
	g = H.open(self, H.fixture("v2_stack"), bus)
	box = [null]
	g.finished.connect(func(res: Dictionary) -> void: box[0] = res)
	await t.frames(1)
	H.key(g, KEY_C)
	H.key(g, KEY_2)
	t.eq(g.ops_log(), [], "C and the digits need a customer coin under the hand")
	t.eq(_hand(g), [g._sample_faces[0]], "but they show the hand")
	H.key(g, KEY_RIGHT)
	H.key(g, KEY_RIGHT)
	H.key(g, KEY_SPACE)
	H.key(g, KEY_C)
	H.key(g, KEY_2)
	for _k in range(4):
		H.key(g, KEY_RIGHT)
	H.key(g, KEY_C)
	H.key(g, KEY_1)
	H.key(g, KEY_DELETE)
	H.key(g, KEY_KP_2)
	_press(g, KEY_C, true, false)
	_press(g, KEY_SPACE, false, true)
	t.eq(g.ops_log(), [["blow", 0], ["clink", 0, 1], ["mark", 0, 2], ["clink", 4, 0], ["mark", 4, 1], ["mark", 4, 0], ["mark", 4, 2]],
		"stack by keys: blow, clink with the next coin, mark the coin under the hand; echo and Ctrl do nothing")
	H.key(g, KEY_F)
	r = box[0] if box[0] != null else {}
	t.eq(r.get("observations", []), ["obs.coin_ring.some_dull", "obs.coin_ring.unsure"], "the keyed marks are the observation")
	t.eq((r.get("measures", {}) as Dictionary).get("marks", []), [2, 0, 0, 0, 2], "marks as keyed")
	await H.drop(self, [g, bus])


## The faces the keyboard hand is drawn on.
func _hand(g: CardCoinRingGame) -> Array:
	var out: Array = []
	for f in g._sample_faces + g._coin_faces:
		if bool(f.get("cursor")):
			out.append(f)
	return out


func _press(g: Node, code: Key, ctrl: bool, echo: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	ev.ctrl_pressed = ctrl
	ev.echo = echo
	g.get_viewport().push_input(ev)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	up.echo = false
	g.get_viewport().push_input(up)


func _digit_text(node: Node) -> PackedStringArray:
	var bad := PackedStringArray()
	var pending: Array = [node]
	while not pending.is_empty():
		var n: Node = pending.pop_back()
		for c in n.get_children():
			pending.append(c)
		var txt := ""
		if n is Label:
			txt = (n as Label).text
		elif n is Button:
			txt = (n as Button).text
		elif n is RichTextLabel:
			txt = (n as RichTextLabel).get_parsed_text()
		if txt == "":
			continue
		if txt.contains("%"):
			bad.append(txt)
			continue
		for i in range(10):
			if txt.contains(str(i)):
				bad.append(txt)
				break
	return bad
