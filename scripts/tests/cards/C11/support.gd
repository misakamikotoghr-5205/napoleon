# C11 test helpers. No class_name.
extends RefCounted

const FIX := "res://scripts/tests/cards/C11/fixtures/"
const STEPS := "res://scripts/tests/cards/C11/guide_steps.json"


static func load_fx(name: String) -> Variant:
	return CardDB.read_json(FIX + name + ".json")


static func path(name: String) -> String:
	return FIX + name + ".json"


static func find(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	if str(root.name) == node_name:
		return root
	for c in root.get_children():
		var f := find(c, node_name)
		if f != null:
			return f
	return null


static func texts(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	_texts(root, out)
	return out


static func no_percent(root: Node) -> bool:
	for s in texts(root):
		if s.contains("%"):
			return false
	return true


static func last_cmd(mock: MockCardEngine, cmd: String) -> Dictionary:
	for i in range(mock.sent.size() - 1, -1, -1):
		var row: Array = mock.sent[i]
		if str(row[0]) == cmd:
			return (row[1] as Dictionary) if row.size() > 1 and typeof(row[1]) == TYPE_DICTIONARY else {}
	return {}


static func count_cmd(mock: MockCardEngine, cmd: String) -> int:
	var n := 0
	for row in mock.sent:
		if str(row[0]) == cmd:
			n += 1
	return n


static func game_cmds(mock: MockCardEngine) -> int:
	var n := 0
	for row in mock.sent:
		if str(row[0]).begins_with("game."):
			n += 1
	return n


static func key(code: Key, shift: bool = false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	ev.shift_pressed = shift
	ev.echo = false
	return ev


## Stage, dialog, checks and hand from CardIds.widget_scene (W0 stubs until C01/C03/C04 land).
static func mount_stage(parent: Node, panel: CardPanel, mock: CardEngineApi, bus: CardEventBus) -> Dictionary:
	var stage: CardStageApi = load(CardIds.widget_scene(&"stage")).instantiate()
	var dialog: CardDialogApi = load(CardIds.widget_scene(&"dialog")).instantiate()
	var checks: CardChecksApi = load(CardIds.widget_scene(&"checks")).instantiate()
	var hand: CardHandApi = load(CardIds.widget_scene(&"hand_fan")).instantiate()
	for node in [stage, checks, dialog, hand]:
		node.set("bus", bus)
		parent.add_child(node)
	checks.set("engine", mock)
	stage.refresh(mock.view())
	panel.bind(mock, bus)
	if panel is CardStagePanel:
		(panel as CardStagePanel).bind_stage(stage, dialog, checks, hand)
	if panel.get_parent() == null:
		parent.add_child(panel)
	return {"panel": panel, "stage": stage, "dialog": dialog, "checks": checks, "hand": hand}


static func dialog_line(dialog: Node, ref: String) -> Dictionary:
	var lines: Variant = dialog.get("_lines")
	if typeof(lines) != TYPE_ARRAY:
		return {}
	for row in lines:
		if typeof(row) == TYPE_DICTIONARY and str((row as Dictionary).get("ref", "")) == ref:
			return row
	return {}


static func widgets(root: Node) -> Array:
	var out: Array = []
	_widgets(root, out)
	return out


static func _texts(n: Node, out: PackedStringArray) -> void:
	if n is Label:
		out.append((n as Label).text)
	elif n is Button:
		out.append((n as Button).text)
	elif n is RichTextLabel:
		out.append((n as RichTextLabel).get_parsed_text())
	for c in n.get_children():
		_texts(c, out)


static func _widgets(n: Node, out: Array) -> void:
	if n is CardSlotWidget:
		out.append(n)
	for c in n.get_children():
		_widgets(c, out)
