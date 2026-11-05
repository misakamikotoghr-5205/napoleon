## Read-only details of a public map node. Requests are sent by the owning screen.
extends PanelContainer

signal command_requested(cmd: StringName, args: Dictionary)
signal card_pressed(uid: String)
const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const Data = preload("res://scripts/cards/ui/map/map_data.gd")
var _body: VBoxContainer
var _buttons: Dictionary = {}

func refresh(map: Dictionary, campaign: Dictionary, node: Dictionary, enabled: bool = true) -> void:
	_ensure()
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_buttons.clear()
	if node.is_empty():
		_label(Data.text("select_node"), 20)
		return
	var id := str(node.get("id", ""))
	var current := id == str(map.get("pos", ""))
	var day := str(campaign.get("phase", "")) == "day" and enabled and not bool(node.get("preview_only", false))
	var state := str(node.get("state", ""))
	_label(str(node.get("label", id)), 23)
	var type := Data.text("types." + str(node.get("type", "?")))
	var role := Data.text("roles." + str(node.get("role", "")))
	_label(type + (" · " + role if role != "" else ""), 16)
	if str(node.get("date", "")) != "":
		_label(str(node["date"]), 15)
	if str(node.get("reason", "")) != "":
		_label(Data.error(str(node["reason"])), 15)
	if state == "fog":
		_label(Data.text("fog_hint"), 15)
	if node.has("level"):
		_label(Data.text("battle_info", {"level": int(node["level"]), "power": int(node.get("power", 0))}), 16)
	if not current:
		var cost: Dictionary = node.get("cost", {})
		if not cost.is_empty():
			_label(Data.text("route_cost", {"mp": int(cost.get("legs", 0)), "supply": int(cost.get("supply", 0)), "gold": int(cost.get("toll", {}).get("gold", 0)), "days": int(cost.get("voyage_days", 0))}), 15)
		_button("move", Data.text("move"), &"campaign.map_move", {"to": id}, day and bool(node.get("reachable", false)))
		if state == "fog":
			_button("scout", Data.text("scout"), &"campaign.map_scout", {"node": id}, day)
		return
	var pending := str(map.get("pending_kind", ""))
	if pending in ["toll", "rival"]:
		var pay: Dictionary = map.get("pay", {})
		_label(Data.text("pending_" + pending), 16)
		var costs := PackedStringArray()
		var cost: Dictionary = pay.get("cost", {})
		for currency in ["gold", "supply", "medal", "intel"]:
			if cost.has(currency):
				costs.append(Data.text("pay_resource", {"n": int(cost[currency]), "resource": Data.text("resources." + currency)}))
		var label := Data.text("pay_cost", {"cost": Data.text("pay_separator").join(costs)}) if not costs.is_empty() else Data.text("pay_toll")
		_button("pay_gold", label, &"campaign.map_pay", {"how": "gold"}, day and bool(pay.get("can_gold", false)))
		_button("pay_prop", Data.text("pay_prop"), &"campaign.map_pay", {"how": "prop"}, day and bool(pay.get("can_prop", false)))
		if pending == "rival":
			_button("pay_fight", Data.text("pay_fight"), &"campaign.map_pay", {"how": "fight"}, day and bool(pay.get("can_fight", false)))
			if bool(pay.get("can_wait", false)):
				_label(Data.text("pay_wait"), 15)
		return
	_button("enter", Data.text("enter"), &"campaign.map_enter", {}, day and str(node.get("reason", "")) == "")
	var event := str(map.get("event", ""))
	if event != "":
		_card_button("event:" + event, Data.text("event_continue"))
	var actions: Array = node.get("actions", [])
	for action_raw in actions:
		var action := str(action_raw)
		if action.begins_with("tile:"):
			_label(Data.text("tile_effect", {"name": Data.action_name(action)}), 15)
		elif action in ["recruit:troop", "recruit:companion"]:
			if action == "recruit:troop":
				for cls in ["line", "grenadier", "jager", "hussar", "artillery"]:
					_action("recruit:troop:" + cls, day)
			else:
				for person in campaign.get("companions", []):
					if not bool(person.get("recruited", false)) and bool(person.get("alive", true)):
						_action("recruit:" + str(person.get("id", "")), day)
		elif action == "fund":
			_action("fund:yes", day)
			_action("fund:no", day)
		else:
			var available := day
			if action == "build_depot":
				available = available and not id in map.get("depots", [])
			elif action == "muster":
				available = available and not bool(map.get("mustered", false))
			_action(action, available)
	for demand in node.get("demands", []):
		_card_button("demand:" + str(demand), Data.text("demand"))
	if id in map.get("depots", []):
		_label(Data.text("depot_built"), 15)

func action_button(id: String) -> Button:
	return _buttons.get(id) as Button

func _action(action: String, enabled: bool) -> void:
	var command := Data.command(action)
	if command.is_empty():
		return
	var key := "build" if action == "build_depot" else action
	_button(key, Data.action_name(action), command["cmd"], command["args"], enabled)

func _button(id: String, label: String, cmd: StringName, args: Dictionary, enabled: bool) -> void:
	var b := Button.new()
	b.name = id.replace(":", "_")
	HdTheme.apply_button(b, "secondary")
	b.text = label
	b.disabled = not enabled
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 38
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(func(): command_requested.emit(cmd, args))
	_body.add_child(b)
	_buttons[id] = b

func _card_button(uid: String, label: String) -> void:
	var b := Button.new()
	HdTheme.apply_button(b, "secondary")
	b.text = label
	b.set_meta("uid", uid)
	b.pressed.connect(func(): card_pressed.emit(uid))
	_body.add_child(b)
	_buttons[uid] = b

func _label(value: String, px: int) -> void:
	var label := HdTheme.make_label(value, px)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(label)

func _ensure() -> void:
	if _body != null:
		return
	add_theme_stylebox_override("panel", HdTheme.panel_box("glass"))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_body)
