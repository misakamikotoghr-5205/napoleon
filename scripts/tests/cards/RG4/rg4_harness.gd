# RG4 test helpers: boot the Mock table on a rogue fixture, walk nodes, push real keys and mouse events,
# check the words on a surface. No class_name (preload). Owner RG4.
extends RefCounted

const FIX := "res://scripts/tests/cards/RG4/fixtures/"
const STOCKTAKE_SCENE := "res://scenes/cards/rogue/StocktakePanel.tscn"
const DRAWER_SCENE := "res://scenes/cards/rogue/RelicsDrawer.tscn"
const TITLE_SCENE := "res://scenes/cards/shell/CardTitle.tscn"


static func boot(tree: SceneTree, bus: CardEventBus, fixture: String, extra: Dictionary = {}) -> CardGameRoot:
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	var opts := {"mock": true, "bus": bus, "skip_title": true, "settings_path": "", "guide": "off",
		"fixture": fixture if fixture.contains("/") or not fixture.begins_with("rogue_") else FIX + fixture + ".json"}
	opts.merge(extra, true)
	game.boot(opts)
	tree.root.add_child(game)
	return game


static func mock(bus: CardEventBus, fixture: String) -> MockCardEngine:
	var m := MockCardEngine.new(bus)
	m.load_fixture(fixture if fixture.contains("/") or not fixture.begins_with("rogue_") else FIX + fixture + ".json")
	return m


static func walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(walk(c))
	return out


## Visible texts (Label / Button / RichTextLabel) under node, in tree order.
static func texts(node: Node) -> Array:
	var out: Array = []
	for n in walk(node):
		if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
			continue
		var txt := ""
		if n is Label:
			txt = (n as Label).text
		elif n is Button:
			txt = (n as Button).text
		elif n is RichTextLabel:
			txt = (n as RichTextLabel).get_parsed_text()
		if txt != "":
			out.append(txt)
	return out


static func count_text(node: Node, text: String) -> int:
	var n := 0
	for txt in texts(node):
		if txt == text:
			n += 1
	return n


static func button_with(node: Node, text: String) -> Button:
	for n in walk(node):
		if n is Button and (n as Button).text == text and (n as Button).is_visible_in_tree():
			return n
	return null


static func key_event(code: Key, down: bool = true, unicode: int = 0) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	ev.unicode = unicode
	return ev


## A real key press (down + up) through the viewport, one frame each.
static func tap(tree: SceneTree, code: Key, unicode: int = 0) -> void:
	tree.root.push_input(key_event(code, true, unicode))
	await tree.process_frame
	tree.root.push_input(key_event(code, false, unicode))
	await tree.process_frame


## Mouse move to point (viewport coordinates), then the hovered control.
static func hover(tree: SceneTree, point: Vector2) -> Control:
	var move := InputEventMouseMotion.new()
	move.position = point
	move.global_position = point
	tree.root.push_input(move, true)
	await tree.process_frame
	return tree.root.gui_get_hovered_control()


## Move, press, release with the left button at point.
static func click(tree: SceneTree, point: Vector2) -> void:
	await hover(tree, point)
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = point
		ev.global_position = point
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		tree.root.push_input(ev, true)
		await tree.process_frame


## Commands the Mock received after index `from` (ui.* left out).
static func sent_since(m: MockCardEngine, from: int) -> Array:
	var out: Array = []
	for i in range(from, m.sent.size()):
		if not str(m.sent[i][0]).begins_with("ui."):
			out.append(m.sent[i])
	return out


## Every text on the surface: no percent sign anywhere; digits only in the allowed texts (visible counts).
static func numbers_ok(t, node: Node, allowed: Array, label: String) -> void:
	var num := RegEx.create_from_string("[0-9]")
	for txt in texts(node):
		t.ok(not str(txt).contains("%"), "%s: no percent in '%s'" % [label, txt])
		if num.search(str(txt)) != null:
			t.ok(allowed.has(txt), "%s: digits only in visible counts, got '%s'" % [label, txt])
	for n in walk(node):
		if n is Control and (n as Control).tooltip_text != "":
			t.ok(num.search((n as Control).tooltip_text) == null or allowed.has((n as Control).tooltip_text),
				"%s: no digits in tooltip '%s'" % [label, (n as Control).tooltip_text])
