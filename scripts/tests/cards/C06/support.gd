# C06 测试共用：开面板、读停针角度、读扇区节点上的 arc_deg。主人 C06。
extends RefCounted

const FIX := "res://scripts/tests/cards/C06/fixtures/"
const FIXTURES: Array[String] = ["month_widen", "big", "fair", "gamble_stake", "no_money"]


static func read_fix(name: String) -> Dictionary:
	var d = CardDB.read_json(FIX + name + ".json")
	return d if typeof(d) == TYPE_DICTIONARY else {}


static func boot(tree: SceneTree) -> Dictionary:
	var bus := CardEventBus.new()
	tree.root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	return {"bus": bus, "mock": mock}


static func open_panel(tree: SceneTree, mock: MockCardEngine, bus: CardEventBus, args: Dictionary) -> CardWheelPanel:
	var panel: CardWheelPanel = load("res://scenes/cards/wheel/WheelPanel.tscn").instantiate()
	panel.bind(mock, bus)
	tree.root.add_child(panel)
	panel.open(args)
	return panel


static func args_of(fix: Dictionary) -> Dictionary:
	var meta: Dictionary = fix.get("_meta", {})
	var args := {"wheel": str(meta.get("wheel", "")), "uid": str(meta.get("uid", ""))}
	if meta.has("required"):
		args["required"] = bool(meta.get("required"))
	return args


static func face(panel: Node) -> Control:
	return panel.find_child("Face", true, false) as Control


## 盘面旋转是逆时针 stop_deg（Godot 正角度为顺时针），换算成相对 12 点钟的顺时针角度。
static func from_twelve(node: Control) -> float:
	return fposmod(-rad_to_deg(node.rotation), 360.0)


static func arc_of(panel: Node, id: String) -> float:
	for n in panel.find_children("*", "Control", true, false):
		if str(n.get_meta("seg_id", "")) == id:
			return float(n.get_meta("arc_deg", -1.0))
	return -1.0


static func sum_arcs(panel: Node) -> float:
	var total := 0.0
	for n in panel.find_children("*", "Control", true, false):
		if str(n.get_meta("seg_id", "")) != "":
			total += float(n.get_meta("arc_deg", 0.0))
	return total


static func wheel_query(fix: Dictionary) -> Dictionary:
	var queries: Dictionary = fix.get("queries", {})
	for k in queries.keys():
		if str(k).begins_with("wheel|"):
			return queries[k]
	return {}


static func spin_rows(fix: Dictionary) -> Array:
	var out: Array = []
	for row in fix.get("responses", []):
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if str(row.get("cmd", "")) == "wheel.spin":
			out.append(row)
	return out


static func stop_inside(segments: Array, id: String, stop: float) -> bool:
	var cursor := 0.0
	for seg in segments:
		if typeof(seg) != TYPE_DICTIONARY:
			continue
		var arc := float(seg.get("arc_deg", 0.0))
		if str(seg.get("id", "")) == id:
			return stop >= cursor - 0.05 and stop < cursor + arc - 0.001
		cursor += arc
	return false


static func has_digit(text: String) -> bool:
	for i in text.length():
		var c := text.unicode_at(i)
		if c >= 48 and c <= 57:
			return true
	return false


static func bad_panel_text(panel: Node) -> PackedStringArray:
	var bad := PackedStringArray()
	for n in panel.find_children("*", "", true, false):
		var text := ""
		if n is Label:
			text = (n as Label).text
		elif n is Button:
			text = (n as Button).text
		elif n is RichTextLabel:
			text = (n as RichTextLabel).get_parsed_text()
		else:
			continue
		if text == "":
			continue
		# The incense slot's money pad shows the player's own step ("-1" / "+1"), not an odd or a hidden value.
		if str(n.name) in ["MoneyMinus", "MoneyPlus"]:
			continue
		if text.contains("%"):
			bad.append(text)
			continue
		if str(n.name) == "CostMoney":
			continue
		if has_digit(text):
			bad.append("%s: %s" % [n.name, text])
	return bad


static func press(panel: Node, node_name: String) -> void:
	var b := panel.find_child(node_name, true, false) as Button
	if b != null:
		b.pressed.emit()


static func sent_cmds(mock: MockCardEngine, cmd: String) -> Array:
	var out: Array = []
	for row in mock.sent:
		if str(row[0]) == cmd:
			out.append(row[1])
	return out
