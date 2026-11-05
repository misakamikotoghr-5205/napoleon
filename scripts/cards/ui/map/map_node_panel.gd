## Modal camp/shop/interlude access; the same public node actions are used on the main map.
extends CardPanel

const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const Data = preload("res://scripts/cards/ui/map/map_data.gd")
const NodeCard = preload("res://scripts/cards/ui/map/map_node_card.gd")
var kind: StringName = &"map"
var fast := false
var _node_id := ""
var _event := ""
var _inventory := false
var _closed := false
var _busy := false
var _node: Control
var _title: Label
var _status: Label
var _event_button: Button
var _back: Button
var _inventory_scroll: ScrollContainer
var _inventory_body: VBoxContainer
var _inventory_buttons: Dictionary = {}

func open(args: Dictionary) -> void:
	_closed = false
	_node_id = str(args.get("node", ""))
	_event = str(args.get("event", ""))
	_inventory = bool(args.get("inventory", false))
	_ensure()
	refresh(engine.view())

func refresh(view: Dictionary) -> void:
	if engine == null or _closed or _busy:
		return
	_ensure()
	var map: Dictionary = engine.query(&"campaign.map")
	var campaign: Dictionary = engine.query(&"campaign")
	if _node_id == "":
		_node_id = str(map.get("pos", ""))
	var node := Data.node(map, _node_id)
	var interlude := kind == &"map_interlude"
	_title.text = Data.text("inventory") if _inventory else (Data.text("interlude") if interlude else str(node.get("label", Data.text("title"))))
	_node.visible = not interlude and not _inventory
	_event_button.visible = interlude
	_inventory_scroll.visible = _inventory
	if _inventory:
		_fill_inventory(view)
	elif interlude:
		_event = str(map.get("interlude", ""))
		_event_button.disabled = _event == ""
		_status.text = Data.text("interlude_hint" if _event != "" else "interlude_done")
	else:
		_node.refresh(map, campaign, node, str(campaign.get("phase", "")) == "day")

func action_button(id: String) -> Button:
	_ensure()
	if id == "interlude":
		return _event_button
	if id == "back":
		return _back
	if _inventory_buttons.has(id):
		return _inventory_buttons[id] as Button
	return _node.action_button(id)

func status_label() -> Label:
	_ensure()
	return _status

func dismiss() -> void:
	_close({})

func autoplay_step() -> bool:
	if _closed:
		return false
	if kind == &"map_interlude" and _event != "":
		_open_card("event:" + _event)
	else:
		_close({})
	return true

func _open_card(uid: String) -> void:
	_close({"open_uid": uid})

func _close(result: Dictionary) -> void:
	if _closed:
		return
	_closed = true
	close_requested.emit(result)

func _send(cmd: StringName, args: Dictionary) -> void:
	if _closed or _busy:
		return
	_busy = true
	var result: Dictionary = engine.send(cmd, args)
	_busy = false
	if not bool(result.get("ok", false)):
		_status.text = Data.error(str(result.get("reason", result.get("err", "unknown"))))
		_status.add_theme_color_override("font_color", HdTheme.color("hd_enemy_hi"))
		return
	_status.text = Data.text("action_done")
	_status.add_theme_color_override("font_color", HdTheme.color("hd_gold_hi"))
	var uid := Data.destination(result)
	if cmd == &"campaign.map_pay" and str(args.get("how", "")) == "fight":
		uid = "battle"
	if uid != "":
		_open_card(uid)
	else:
		refresh(engine.view())

func _fill_inventory(view: Dictionary) -> void:
	for child in _inventory_body.get_children():
		_inventory_body.remove_child(child)
		child.queue_free()
	_inventory_buttons.clear()
	for group in ["kept", "contacts"]:
		var heading := HdTheme.make_label(Data.text("inventory_" + group), 21)
		_inventory_body.add_child(heading)
		for row in view.get(group, []):
			var uid := str(row.get("uid", ""))
			if uid == "" or _inventory_buttons.has(uid):
				continue
			var card: Dictionary = engine.query(&"card", {"uid": uid})
			var title := CardText.card(str(card.get("def", row.get("def", ""))), "title")
			var button := Button.new()
			HdTheme.apply_button(button, "secondary")
			button.text = title if title != "" else Data.text("inventory_item")
			button.set_meta("uid", uid)
			button.pressed.connect(func(): _open_card(uid))
			_inventory_body.add_child(button)
			_inventory_buttons[uid] = button
	_status.text = Data.text("inventory_empty" if _inventory_buttons.is_empty() else "inventory_hint")

func _ensure() -> void:
	if _node != null:
		return
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	HdTheme.apply_hd_filter(self)
	var background := ColorRect.new()
	background.color = HdTheme.color("hd_ink")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_title = HdTheme.make_label("", 30, "serif")
	_title.position = Vector2(280, 34)
	_title.size = Vector2(720, 50)
	add_child(_title)
	_node = NodeCard.new()
	_node.position = Vector2(280, 100)
	_node.size = Vector2(720, 470)
	_node.command_requested.connect(_send)
	_node.card_pressed.connect(_open_card)
	add_child(_node)
	_inventory_scroll = ScrollContainer.new()
	_inventory_scroll.position = Vector2(280, 100)
	_inventory_scroll.size = Vector2(720, 470)
	_inventory_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_inventory_scroll)
	_inventory_body = VBoxContainer.new()
	_inventory_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_body.add_theme_constant_override("separation", 8)
	_inventory_scroll.add_child(_inventory_body)
	_event_button = Button.new()
	HdTheme.apply_button(_event_button, "primary")
	_event_button.position = Vector2(400, 260)
	_event_button.size = Vector2(480, 72)
	_event_button.text = Data.text("interlude_open")
	_event_button.pressed.connect(func(): _open_card("event:" + _event))
	add_child(_event_button)
	_status = HdTheme.make_label("", 17)
	_status.position = Vector2(280, 588)
	_status.size = Vector2(720, 46)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	_back = Button.new()
	HdTheme.apply_button(_back, "secondary")
	_back.position = Vector2(510, 646)
	_back.size = Vector2(260, 48)
	_back.text = Data.text("back")
	_back.pressed.connect(dismiss)
	add_child(_back)
