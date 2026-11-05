# C09 test helpers. No class_name.
extends RefCounted


static func mount(tree: SceneTree, fixture: String) -> Dictionary:
	var bus := CardEventBus.new()
	tree.root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	if fixture != "":
		mock.load_fixture(fixture)
	return {"bus": bus, "mock": mock}


static func open_panel(tree: SceneTree, pack: Dictionary, scene: String) -> CardPanel:
	var p: CardPanel = load(scene).instantiate()
	p.bind(pack["mock"], pack["bus"])
	tree.root.add_child(p)
	p.open({})
	return p


static func fast_anim_file(on: bool) -> void:
	var path := "user://cards/settings.json"
	if not on:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string("{\"fast_anim\":true}")
	f.close()


static func goals_visible(panel: Node) -> bool:
	var goals := panel.find_child("Goals", true, false) as CanvasItem
	return goals != null and goals.visible


static func mount_stage(tree: SceneTree, view: Dictionary, night: bool) -> Node:
	var stage: Node = load(CardIds.widget_scene(&"stage")).instantiate()
	tree.root.add_child(stage)
	if stage is Control:
		var box := stage as Control
		box.set_anchors_preset(Control.PRESET_TOP_LEFT)
		box.position = Vector2.ZERO
		box.size = Vector2(1280, 720)
	var shown := view.duplicate(true)
	if night:
		var block: Dictionary = {}
		if typeof(shown.get("stage")) == TYPE_DICTIONARY:
			block = (shown["stage"] as Dictionary).duplicate(true)
		block["set"] = "counter"
		block["time"] = "night"
		block["sealed"] = false
		shown["stage"] = block
	if stage.has_method("refresh"):
		stage.call("refresh", shown)
	return stage


static func tap(panel: Control, key: Key) -> void:
	if panel.is_inside_tree():
		panel.grab_focus()
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.physical_keycode = key
	ev.pressed = true
	ev.echo = false
	panel._gui_input(ev)


static func count_cmd(mock: MockCardEngine, cmd: String) -> int:
	var n := 0
	for row in mock.sent:
		if str(row[0]) == cmd:
			n += 1
	return n


static func blob(node: Node) -> String:
	var parts: PackedStringArray = []
	var stack: Array = [node]
	while not stack.is_empty():
		var n := stack.pop_back() as Node
		var txt := ""
		if n is Label:
			txt = (n as Label).text
		elif n is Button:
			txt = (n as Button).text
		elif n is RichTextLabel:
			txt = (n as RichTextLabel).get_parsed_text()
		if txt != "":
			parts.append(txt)
		for c in n.get_children():
			stack.append(c)
	return "\n".join(parts)


static func has_percent(node: Node) -> bool:
	return blob(node).contains("%")


static func joined(node: Node) -> String:
	return blob(node)


static func drain(panel: CardPanel, limit: int = 30) -> int:
	var n := 0
	while n < limit and panel.autoplay_step():
		n += 1
	return n


static func guide_data() -> Dictionary:
	var d = CardDB.read_json("res://scripts/tests/cards/C09/guide_steps.json")
	return d if typeof(d) == TYPE_DICTIONARY else {}


static func attach_guide(tree: SceneTree, pack: Dictionary) -> CardGuide:
	var guide: CardGuide = load("res://scenes/cards/shell/GuideOverlay.tscn").instantiate()
	tree.root.add_child(guide)
	guide.bind(pack["mock"], pack["bus"])
	guide.force(true)
	guide.skip_fades = true
	guide.load_steps(guide_data())
	return guide


static func stage_1938() -> Dictionary:
	var d = CardDB.read_json("res://data/cards/era/1938/stage.json")
	if typeof(d) != TYPE_DICTIONARY:
		d = CardDB.read_json("res://data/cards/_examples/era/1938/stage.json")
	return d if typeof(d) == TYPE_DICTIONARY else {}
