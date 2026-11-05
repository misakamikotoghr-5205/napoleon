# Shared helpers for C07 tests. No class_name.
extends RefCounted

const FIX := "res://scripts/tests/cards/C07/fixtures/"
const UID := "c0701"
const PANEL := "res://scenes/cards/fortune/FortunePanel.tscn"
const STRIP := "res://scenes/cards/fortune/AlmanacStrip.tscn"


static func mock(bus: CardEventBus, name: String) -> MockCardEngine:
	var m := MockCardEngine.new(bus)
	m.load_fixture(FIX + name + ".json")
	return m


static func walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(walk(c))
	return out


static func button_by_key(root: Node, key: String) -> Button:
	var want := CardText.ui(key)
	for n in walk(root):
		if n is Button and (n as Button).text == want:
			return n
	return null


static func char_buttons(root: Node) -> Array:
	var out: Array = []
	for n in walk(root):
		if n is Button and (n as Button).has_meta("char_id"):
			out.append(n)
	return out


static func count_text(root: Node, text: String) -> int:
	var n := 0
	for node in walk(root):
		if node is Label and (node as Label).text == text:
			n += 1
		elif node is Button and (node as Button).text == text:
			n += 1
	return n


static func sent(m: MockCardEngine, cmd: String) -> Array:
	var out: Array = []
	for row in m.sent:
		if str(row[0]) == cmd:
			out.append(row[1])
	return out


static func key_event(code: Key, shift: bool = false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.echo = false
	ev.keycode = code
	ev.physical_keycode = code
	ev.shift_pressed = shift
	return ev
