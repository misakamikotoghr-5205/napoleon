# C05 测试共用：开夹具、面板、牌桌，查发出的指令。没有 class_name。
extends RefCounted

const FIX := "res://scripts/tests/cards/C05/fixtures/"
const PANEL := "res://scenes/cards/demand/DemandPanel.tscn"
const BOARD := "res://scenes/cards/demand/DemandBoard.tscn"
const ROOT := "res://scenes/cards/CardGame.tscn"
const STEPS := "res://scripts/tests/cards/C05/guide_steps.json"


static func load_doc(name: String) -> Dictionary:
	var d = CardDB.read_json(FIX + name)
	return d if typeof(d) == TYPE_DICTIONARY else {}


static func engine(bus: CardEventBus, name: String) -> MockCardEngine:
	var eng := MockCardEngine.new(bus)
	eng.load_fixture(FIX + name)
	return eng


static func mount_panel(tree: SceneTree, eng: MockCardEngine, bus: CardEventBus, uid: String) -> CardDemandPanel:
	var panel: CardDemandPanel = load(PANEL).instantiate()
	tree.root.add_child(panel)
	panel.bind(eng, bus)
	panel.open({"uid": uid})
	return panel


static func mount_board(tree: SceneTree) -> CardDemandBoard:
	var board: CardDemandBoard = load(BOARD).instantiate()
	board.position = Vector2(1056, 64)
	board.size = Vector2(216, 220)
	tree.root.add_child(board)
	return board


static func boot(tree: SceneTree, bus: CardEventBus, name: String) -> CardGameRoot:
	var game: CardGameRoot = load(ROOT).instantiate()
	tree.root.add_child(game)
	game.boot({"mock": true, "bus": bus, "fixture": FIX + name, "skip_title": true})
	return game


static func guide(game: CardGameRoot) -> void:
	game.guide.force(true)
	game.guide.skip_fades = true
	game.guide.load_steps(steps())


static func steps() -> Dictionary:
	var d = CardDB.read_json(STEPS)
	return d if typeof(d) == TYPE_DICTIONARY else {}


static func key(code: Key, shift: bool = false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	ev.echo = false
	ev.shift_pressed = shift
	return ev


static func sent_has(eng: MockCardEngine, cmd: String, match: Dictionary) -> bool:
	for row in eng.sent:
		if str(row[0]) != cmd:
			continue
		var args: Dictionary = row[1]
		var hit := true
		for k in match.keys():
			if _js(args.get(k)) != _js(match[k]):
				hit = false
				break
		if hit:
			return true
	return false


static func sent_place(eng: MockCardEngine, uid: String, slot: String, source: Dictionary) -> bool:
	for row in eng.sent:
		if str(row[0]) != "slot.place":
			continue
		var args: Dictionary = row[1]
		if str(args.get("uid", "")) != uid or str(args.get("slot", "")) != slot:
			continue
		if _js(args.get("source", {})) == _js(source):
			return true
	return false


static func leak_paths(doc: Dictionary) -> PackedStringArray:
	var bad := PackedStringArray()
	bad.append_array(CardViewModel.leaks(doc.get("view", {})))
	for k in doc.get("queries", {}).keys():
		bad.append_array(CardViewModel.leaks(doc["queries"][k]))
	for row in doc.get("responses", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		bad.append_array(CardViewModel.leaks(row.get("result", {})))
		for ev in row.get("events", []):
			bad.append_array(CardViewModel.leaks(ev))
		for p in row.get("patch", []):
			if typeof(p) == TYPE_DICTIONARY:
				bad.append_array(CardViewModel.leaks(p.get("value")))
	return bad


static func percent_text(node: Node) -> PackedStringArray:
	var bad := PackedStringArray()
	_percent(node, bad)
	return bad


static func _percent(node: Node, bad: PackedStringArray) -> void:
	var txt := ""
	if node is Label:
		txt = (node as Label).text
	elif node is Button:
		txt = (node as Button).text
	elif node is RichTextLabel:
		txt = (node as RichTextLabel).get_parsed_text()
	if txt.contains("%"):
		bad.append(txt)
	for c in node.get_children():
		_percent(c, bad)


static func skip_dialog(panel: CardDemandPanel) -> void:
	if panel != null and panel.dialog != null and not panel.dialog.is_idle():
		panel.dialog.skip()


static func dialog_line(panel: CardDemandPanel) -> String:
	if panel == null or panel.dialog == null:
		return ""
	for n in panel.dialog.find_children("*", "Label", true, false):
		var lab := n as Label
		if lab.get_theme_font_size("font_size") == 18:
			return lab.text
	return ""


static func reply_button(panel: CardDemandPanel, ref: String) -> Button:
	if panel == null or panel.dialog == null:
		return null
	var want := CardText.ui(ref)
	for n in panel.dialog.find_children("*", "Button", true, false):
		var btn := n as Button
		if btn.text == want:
			return btn
	return null


static func mode_ids(panel: CardDemandPanel) -> Array:
	var out: Array = []
	if panel == null or panel.dialog == null:
		return out
	var by_text := {}
	for id in ["pay", "haggle", "substitute", "fabricate", "send_person", "inform"]:
		by_text[CardText.ui("c05.mode." + id)] = id
	for n in panel.dialog.find_children("*", "Button", true, false):
		var btn := n as Button
		if by_text.has(btn.text):
			out.append(by_text[btn.text])
	return out


static func slot_widget(panel: CardDemandPanel, sid: String) -> CardSlotWidget:
	var root: Node = panel.checks if panel != null and panel.checks != null else panel
	if root == null:
		return null
	for n in root.find_children("*", "CardSlotWidget", true, false):
		var widget := n as CardSlotWidget
		if str(widget._slot.get("id", "")) == sid:
			return widget
	return null


static func mount_stage(parent: Node, view: Dictionary) -> Node:
	var packed: PackedScene = load(CardIds.widget_scene(&"stage")) as PackedScene
	var stage: Node = packed.instantiate()
	parent.add_child(stage)
	if stage.has_method("refresh"):
		stage.refresh(view)
	return stage


static func _js(v) -> String:
	return JSON.stringify(CardState.int_restore(v))
