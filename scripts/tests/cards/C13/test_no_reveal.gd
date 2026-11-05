# 不露底（DESIGN P5、§13）：从打开到交回，界面不告诉玩家对不对。
# - 好的和哑的两局走同一串 op：除了余音线本身（那就是证据），节点的样子（字、颜色、显隐、位置、样式）一模一样；交回之后也一样；
# - 界面文字都来自 CardText，没有数字、没有“%”、没有任何观察键的正文；鼠标停住的提示也一样；
# - 不用 good / bad / danger 这类对错色；mg_tool 事件只带 kind 和 tool。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C13/harness.gd")
const VERDICT_COLORS := [&"good", &"bad", &"danger", &"warn", &"money_up", &"money_down"]
const TOOLS := ["blow", "clink", "mark", "call"]


func _initialize() -> void:
	var t := T.new(self, H.arg("name", "C13_no_reveal"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	CardText.setup(CardDB.load_all(CardDB.DEFAULT_ROOT, {}))
	var single: Array = [["blow", -1], ["blow", -2], ["blow", 0], ["call", 2]]
	await _pair(t, "v2_good", "v2_dull", single)
	await _pair(t, "v2_worn", "v2_wellmade", [["blow", -2], ["blow", 0], ["blow", -1], ["call", 1]])
	var stack: Array = [["blow", -1], ["blow", 2], ["blow", 0], ["clink", 2, 3], ["mark", 2, 2], ["mark", 0, 1]]
	var swapped := H.fixture("v2_stack")
	# Same roll, but coin 2 (dull) and coin 3 (good) trade places: the screen must not care which is which.
	var coins: Array = swapped["coins"]
	var tmp = coins[2]
	coins[2] = coins[3]
	coins[3] = tmp
	await _pair_fix(t, H.fixture("v2_stack"), swapped, stack, "stack")


## Same params, only the customer's coins differ (that is all the hidden truth there is).
func _pair(t, a: String, b: String, ops: Array) -> void:
	var fa := H.fixture(a)
	var fb := fa.duplicate(true)
	fb["coins"] = H.fixture(b)["coins"]
	await _pair_fix(t, fa, fb, ops, "%s/%s" % [a, b])


func _pair_fix(t, fa: Dictionary, fb: Dictionary, ops: Array, label: String) -> void:
	var sa: Dictionary = await _play(t, fa, ops, label + " A")
	var sb: Dictionary = await _play(t, fb, ops, label + " B")
	t.eq(sa["before"], sb["before"], label + ": the screen looks the same before done")
	t.eq(sa["after"], sb["after"], label + ": the screen looks the same after done")
	t.eq(sa["tools"], sb["tools"], label + ": same mg_tool events")
	t.eq(sa["held"], sb["held"], label + ": same lines held in the sound box")


func _play(t, fix: Dictionary, ops: Array, label: String) -> Dictionary:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var events: Array = []
	bus.ui_event.connect(func(n: StringName, a: Dictionary) -> void: events.append([str(n), a]))
	var g := H.open(self, fix, bus)
	await t.frames(1)
	for op in ops:
		t.ok(g.apply_op(op), "%s: op %s" % [label, op])
	await t.frames(1)
	var before := _snapshot(g)
	_texts(t, g, label)
	_no_verdict_colors(t, before, label)
	var held: Array = g._wave.held()
	g.apply_op(["done"])
	await t.frames(1)
	var after := _snapshot(g)
	var tools: Array = []
	for e in events:
		t.eq(e[0], "mg_tool", "%s: only mg_tool events" % label)
		var keys: Array = (e[1] as Dictionary).keys()
		keys.sort()
		t.eq(keys, ["kind", "tool"], "%s: mg_tool carries kind and tool only" % label)
		t.ok(TOOLS.has(str(e[1].get("tool", ""))), "%s: known tool %s" % [label, e[1]])
		tools.append(str(e[1].get("tool", "")))
	await H.drop(self, [g, bus])
	return {"before": before, "after": after, "tools": tools, "held": held}


## 每个节点看得见的样子（余音框里画的线除外）。
func _snapshot(g: Node) -> Array:
	var out: Array = []
	for pair in _walk_indexed(g, ""):
		var n: Node = pair[1]
		var row := [pair[0], n.get_class()]
		if n is CanvasItem:
			var ci := n as CanvasItem
			row.append_array([ci.visible, ci.modulate.to_html(), ci.self_modulate.to_html()])
		if n is Control:
			var c := n as Control
			row.append_array([c.position, c.size, c.tooltip_text, c.mouse_default_cursor_shape])
			for slot in ["font_color", "font_hover_color", "font_pressed_color"]:
				if c.has_theme_color_override(slot):
					row.append(c.get_theme_color(slot).to_html())
			for slot in ["normal", "hover", "pressed", "disabled", "panel"]:
				if c.has_theme_stylebox_override(slot):
					var sb := c.get_theme_stylebox(slot)
					if sb is StyleBoxFlat:
						row.append([(sb as StyleBoxFlat).bg_color.to_html(), (sb as StyleBoxFlat).border_color.to_html()])
		if n is Label:
			row.append((n as Label).text)
		elif n is Button:
			row.append([(n as Button).text, (n as Button).disabled])
		elif n is ColorRect:
			row.append((n as ColorRect).color.to_html())
		elif n is TextureRect:
			row.append(str((n as TextureRect).texture.resource_path if (n as TextureRect).texture != null else ""))
		out.append(row)
	return out


func _no_verdict_colors(t, snap: Array, label: String) -> void:
	var verdict: Array = []
	for c in VERDICT_COLORS:
		verdict.append(CardTheme.color(c).to_html())
	var hits: Array = []
	for row in snap:
		var flat := JSON.stringify(row)
		for v in verdict:
			if flat.contains("\"%s\"" % v):
				hits.append(row[0])
	t.eq(hits, [], label + ": no right/wrong colors on any node")


func _texts(t, g: Node, label: String) -> void:
	t.eq(t.all_text_from_cardtext(g), PackedStringArray(), label + ": every text comes from CardText")
	var obs_text := PackedStringArray()
	var cat: Dictionary = CardDB.load_all(CardDB.DEFAULT_ROOT, {}).obs_catalog(&"coin_ring")
	for k in cat.keys():
		var s := CardText.obs(str(k))
		if s != "":
			obs_text.append(s)
	for n in _walk(g):
		var txt := ""
		if n is Label:
			txt = (n as Label).text
		elif n is Button:
			txt = (n as Button).text
		if n is Control and (n as Control).tooltip_text != "":
			txt += (n as Control).tooltip_text
		if txt == "":
			continue
		t.ok(not txt.contains("%"), "%s: no percent in '%s'" % [label, txt])
		var digit := false
		for d in range(10):
			digit = digit or txt.contains(str(d))
		t.ok(not digit, "%s: no digits in '%s'" % [label, txt])
		for s in obs_text:
			t.ok(not txt.contains(s), "%s: no observation text on screen ('%s')" % [label, s])


## [index path, node] for every node; index paths do not depend on auto-generated names.
func _walk_indexed(n: Node, at: String) -> Array:
	var out: Array = [[at, n]]
	for i in range(n.get_child_count()):
		out.append_array(_walk_indexed(n.get_child(i), "%s/%d" % [at, i]))
	return out


func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out
