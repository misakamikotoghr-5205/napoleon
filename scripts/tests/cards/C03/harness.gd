# C03 测试共用：开夹具、查泄漏、查界面文字。主人 C03。
extends RefCounted

const FIXTURES: Array[String] = ["event_slots", "fate_choices", "gold_story", "slot_reject", "read_news",
	"read_ticket", "contacts_full", "kept_full", "roll_fail", "stage_police"]


static func leaks_all(t) -> void:
	for name in FIXTURES:
		var data = CardDB.read_json("res://scripts/tests/cards/C03/fixtures/%s.json" % name)
		t.no_leaks(data, name)


static func boot(tree: SceneTree, fx: String) -> Array:
	var bus := CardEventBus.new()
	tree.root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture("res://scripts/tests/cards/C03/fixtures/%s.json" % fx)
	mock.sent.clear()
	return [bus, mock]


static func open_panel(tree: SceneTree, mock: MockCardEngine, bus: CardEventBus, scene: String, args: Dictionary) -> CardPanel:
	var panel := (load(scene) as PackedScene).instantiate() as CardPanel
	panel.bind(mock, bus)
	tree.root.add_child(panel)
	panel.open(args)
	if panel is CardSlotPanel:
		var dialog := (panel as CardSlotPanel).dialog
		if dialog != null and not dialog.is_idle():
			dialog.skip()
	return panel


static func ui_ok(t, node: Node) -> void:
	var bad: PackedStringArray = t.all_text_from_cardtext(node)
	t.ok(bad.is_empty(), "text from CardText: %s" % ", ".join(bad))
	var pct := PackedStringArray()
	for n in _walk(node):
		var txt := _text_of(n)
		if txt.contains("%"):
			pct.append(txt)
	t.ok(pct.is_empty(), "percent on ui: %s" % ", ".join(pct))


static func cmds(mock: MockCardEngine, cmd: String) -> Array:
	var out: Array = []
	for row in mock.sent:
		if str(row[0]) == cmd:
			out.append(row[1])
	return out


static func guide_done(mock: MockCardEngine, step: String) -> bool:
	for row in mock.sent:
		if str(row[0]) != "ui.guide":
			continue
		var args: Dictionary = row[1]
		if str(args.get("step", "")) == step and str(args.get("status", "")) == "done":
			return true
	return false


static func drive(tree: SceneTree, panel: CardPanel, limit: int = 8) -> int:
	var n := 0
	while panel.autoplay_step() and n < limit:
		n += 1
		await tree.process_frame
	return n


static func drop(tree: SceneTree, nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n) and n is Node:
			(n as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


static func _text_of(n: Node) -> String:
	if n is Label:
		return (n as Label).text
	if n is Button:
		return (n as Button).text
	if n is RichTextLabel:
		return (n as RichTextLabel).get_parsed_text()
	return ""


static func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out
