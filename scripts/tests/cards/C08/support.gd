# C08 tests: fixture load, key taps, hidden-text scan. No class_name.
# Owner C08. docs/handoff_cards/C08_night-settle.md
extends RefCounted

# Warm C05 demand static PackedScene table + C08 panel scripts before timed opens.
const _WarmDemand := preload("res://scripts/cards/ui/demand/demand_panel.gd")
const _WarmNight := preload("res://scenes/cards/night/NightPanel.tscn")
const _WarmSettle := preload("res://scenes/cards/night/SettlePanel.tscn")
const _WarmEnd := preload("res://scenes/cards/night/EndDayConfirm.tscn")
const FIX := "res://scripts/tests/cards/C08/fixtures/"


static func _warm() -> void:
	# Keep the preloads live and instantiate once so timed open_panel measures UI work only.
	if _WarmDemand == null or _WarmNight == null or _WarmSettle == null or _WarmEnd == null:
		push_error("C08 support: warm preloads failed")
		return
	for packed in [_WarmNight, _WarmSettle, _WarmEnd]:
		var node: Node = packed.instantiate()
		node.free()


static func fixture(name: String) -> String:
	return FIX + name + ".json"


static func leaks(t, names: Array) -> void:
	for name in names:
		var doc = CardDB.read_json(fixture(str(name)))
		t.ok(typeof(doc) == TYPE_DICTIONARY, str(name) + " fixture reads")
		if typeof(doc) != TYPE_DICTIONARY:
			continue
		t.eq(str(doc.get("_meta", {}).get("owner", "")), "C08", str(name) + " owner")
		t.no_leaks(doc.get("view", {}), str(name) + " view")
		var queries = doc.get("queries", {})
		if typeof(queries) != TYPE_DICTIONARY:
			continue
		for key in queries.keys():
			t.no_leaks(queries[key], "%s %s" % [name, key])


static func mount(tree: SceneTree, name: String) -> Array:
	_warm()
	var bus := CardEventBus.new()
	tree.root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(fixture(name))
	var host := CardModalHost.new()
	host.bind(mock, bus)
	tree.root.add_child(host)
	return [bus, mock, host]


static func cmds(mock: MockCardEngine, cmd: String) -> Array:
	var out: Array = []
	for row in mock.sent:
		if str(row[0]) == cmd:
			out.append(row)
	return out


static func child(root: Node, pattern: String) -> Node:
	return root.find_child(pattern, true, false)


static func widgets(root: Node) -> Array:
	return root.find_children("*", "CardWidget", true, false)


## Night offers in the fan. C02's fan also keeps a zoom Preview and a sleep face.
static func offers(root: Node) -> Array:
	if _real_fan(root):
		var out: Array = []
		for card in _faces(root):
			if not is_sleep(card):
				out.append(card)
		return out
	return widgets(root)


static func sleep_card(root: Node) -> Node:
	for card in _faces(root):
		if is_sleep(card):
			return card
	return button_with(root, CardText.ui("w0.hand.sleep"))


static func is_sleep(card: CardWidget) -> bool:
	var title := card.get_node_or_null("Title") as Label
	return title != null and title.text == CardText.ui("c02.night.none")


static func button_with(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node
	return null


## C02 plays the selected face. The W0 stub plays on the second press.
static func play_hand(card: CardWidget) -> void:
	var fan := _fan_of(card)
	if fan is CardHandFan:
		var faces := _faces(fan)
		for i in faces.size():
			if faces[i] == card:
				(fan as CardHandApi).select_index(i)
				(fan as CardHandApi).play_selected()
				return
	card.pressed.emit(card.get_uid())
	card.pressed.emit(card.get_uid())


static func play_sleep(root: Node) -> void:
	var node := sleep_card(root)
	if node is CardWidget:
		play_hand(node)
		play_hand(node)
	elif node is Button:
		(node as Button).pressed.emit()
		(node as Button).pressed.emit()


static func _real_fan(root: Node) -> bool:
	return not root.find_children("*", "CardHandFan", true, false).is_empty()


static func _faces(root: Node) -> Array:
	return root.find_children("Face", "CardWidget", true, false)


static func _fan_of(node: Node) -> Node:
	var current := node
	while current != null:
		if current is CardHandFan:
			return current
		current = current.get_parent()
	return null


## W0 draws a flat frame; C02 draws frame.gold when that nine-patch exists.
static func gold_frame(card: CardWidget) -> bool:
	var flat := card.get_node_or_null("FrameFlat") as Panel
	if flat != null and flat.visible:
		var style := flat.get_theme_stylebox(&"panel") as StyleBoxFlat
		if style != null and style.border_color == CardTheme.color(&"frame_gold"):
			return true
	var nine := card.get_node_or_null("FrameNine") as NinePatchRect
	if nine != null and nine.visible and nine.texture != null:
		return true
	if card.get_child_count() < 1:
		return false
	var frame := card.get_child(0) as Panel
	if frame == null:
		return false
	var box := frame.get_theme_stylebox(&"panel") as StyleBoxFlat
	return box != null and box.border_color == CardTheme.color(&"frame_gold")


## W0 tints the whole card; C02 shows the Hi plate.
static func highlighted(card: CardWidget) -> bool:
	if card.modulate == CardTheme.color(&"lamp"):
		return true
	var hi := card.get_node_or_null("Hi") as CanvasItem
	return hi != null and hi.visible


static func tap(tree: SceneTree, code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	ev.echo = false
	Input.parse_input_event(ev)
	await tree.process_frame
	await tree.process_frame


static func blob(root: Node) -> String:
	var text := ""
	var pending: Array = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		if node is Label:
			text += (node as Label).text + "\n"
		elif node is Button:
			text += (node as Button).text + "\n"
	return text


static func no_hidden_numbers(t, root: Node) -> void:
	var text := blob(root)
	t.ok(text.find("%") < 0, "no percent sign in " + text)
	t.ok(text.find("rep_points") < 0 and text.find("heat_points") < 0, "no meter points")
	t.ok(text.find("conscience") < 0, "no conscience")
	t.ok(text.find("g03.tier") < 0, "tier args are not printed raw")
