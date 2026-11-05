## Campaign map screen. All game state comes from public queries; the model owns command validation.
extends Control

signal card_pressed(uid: String)
signal end_pressed
signal open_requested(kind: StringName, args: Dictionary)
signal menu_pressed

const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const Data = preload("res://scripts/cards/ui/map/map_data.gd")
const Canvas = preload("res://scripts/cards/ui/map/map_canvas.gd")
const NodeCard = preload("res://scripts/cards/ui/map/map_node_card.gd")
const Hand = preload("res://scripts/cards/ui/map/map_hand.gd")

var engine: CardEngineApi
var fast := false
var reveal_map := false
var _view: Dictionary = {}
var _campaign: Dictionary = {}
var _map: Dictionary = {}
var _selected := ""
var _built := false
var _busy := false
var _canvas: Control
var _node: Control
var _hand: HBoxContainer
var _cards: HBoxContainer
var _title: Label
var _metrics: Label
var _status: Label
var _daily: Label
var _steps: SpinBox
var _end: Button
var _actions: Dictionary = {}
var _card_buttons: Dictionary = {}

func _init() -> void:
	name = "Map"
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	HdTheme.apply_hd_filter(self)

func bind(p_engine: CardEngineApi) -> void:
	engine = p_engine

func refresh(view: Dictionary, covered: bool = false) -> void:
	_view = view
	if engine == null or _busy or (covered and _built):
		return
	_ensure()
	_campaign = engine.query(&"campaign")
	_map = engine.query(&"campaign.map", {"reveal": true} if reveal_map else {})
	var run: Dictionary = engine.query(&"campaign.run")
	var current := Data.node(_map, str(_map.get("pos", "")))
	if Data.node(_map, _selected).is_empty():
		_selected = str(_map.get("pos", ""))
	_title.text = str(run.get("title", Data.text("title"))) + " · " + str(current.get("label", ""))
	var coins: Dictionary = _campaign.get("coins", {})
	var gauges: Dictionary = {}
	for gauge in _campaign.get("gauges", []):
		gauges[str(gauge.get("id", ""))] = int(gauge.get("value", gauge.get("amount", 0)))
	_metrics.text = Data.text("metrics", {"mp": int(_map.get("mp", 0)), "days": int(_map.get("days", 0)),
		"max": int(_map.get("days_max", 0)), "stamps": int(_map.get("stamps", 0)), "need": int(_map.get("stamps_need", 0)),
		"gold": int(coins.get("gold", 0)), "supply": int(coins.get("supply", 0)), "intel": int(coins.get("intel", 0)),
		"medal": int(coins.get("medal", 0)), "treasury": int(gauges.get("treasury", 0)), "vitality": int(gauges.get("vitality", 0))})
	var gauge_details := PackedStringArray()
	for id in gauges:
		var label := Data.text("resources." + str(id))
		if label != "":
			gauge_details.append(label + " " + str(gauges[id]))
	_metrics.tooltip_text = "\n".join(gauge_details)
	_canvas.refresh(_map)
	_canvas.select_node(_selected)
	_node.refresh(_map, _campaign, Data.node(_map, _selected), _day())
	_hand.refresh(_map, _day())
	var can_roll := _day() and bool(_map.get("can_roll", false))
	_actions["roll"].disabled = not can_roll
	_actions["roll_fixed"].disabled = not can_roll
	_steps.editable = can_roll
	_actions["interlude"].visible = str(_map.get("interlude", "")) != ""
	_daily.text = Data.text("roll_hint" if can_roll else "roll_spent")
	_fill_cards()

func select_node(id: String) -> void:
	if Data.node(_map, id).is_empty():
		return
	_selected = id
	_canvas.select_node(id)
	_node.refresh(_map, _campaign, Data.node(_map, id), _day())

func set_end_state(title: String, sub: String, tone: String) -> void:
	_ensure()
	HdTheme.apply_button(_end, "danger" if tone == "confirm" else ("primary" if tone == "ready" else "secondary"))
	_end.add_theme_font_size_override("font_size", 18)
	_end.text = title + ("\n" + sub if sub != "" else "")

func pending_parts() -> PackedStringArray:
	var result := PackedStringArray()
	if not _day():
		return result
	if str(_map.get("pending_kind", "")) != "":
		result.append(Data.text("pending_node"))
	if str(_map.get("event", "")) != "":
		result.append(Data.text("event_continue"))
	if str(_map.get("interlude", "")) != "":
		result.append(Data.text("interlude"))
	return result

func action_button(id: String) -> Button:
	_ensure()
	return _actions.get(id, _node.action_button(id)) as Button

func card_button(uid: String) -> Button:
	return _card_buttons.get(uid, _node.action_button(uid) if _node != null else null) as Button

func end_button() -> Button:
	_ensure()
	return _end

func map_canvas() -> Control:
	_ensure()
	return _canvas

func node_card() -> Control:
	_ensure()
	return _node

func map_hand() -> HBoxContainer:
	_ensure()
	return _hand

func fixed_steps() -> SpinBox:
	_ensure()
	return _steps

func status_label() -> Label:
	_ensure()
	return _status

func _day() -> bool:
	return str(_campaign.get("phase", _view.get("phase", ""))) == "day"

func _send(cmd: StringName, args: Dictionary) -> void:
	if engine == null or _busy:
		return
	_busy = true
	var result: Dictionary = engine.send(cmd, args)
	_busy = false
	if not bool(result.get("ok", false)):
		_status.text = Data.error(str(result.get("reason", result.get("err", "unknown"))))
		_status.add_theme_color_override("font_color", HdTheme.color("hd_enemy_hi"))
		refresh(engine.view())
		return
	_status.text = Data.text("roll_result", {"n": result["steps"]}) if result.has("steps") else Data.text("action_done")
	_status.add_theme_color_override("font_color", HdTheme.color("hd_gold_hi"))
	if cmd in [&"campaign.map_move", &"campaign.map_pay"]:
		_selected = ""
	refresh(engine.view())
	var uid := Data.destination(result)
	if cmd == &"campaign.map_pay" and str(args.get("how", "")) == "fight":
		uid = "battle"
	if uid != "":
		card_pressed.emit(uid)
	elif cmd == &"campaign.map_enter" and str(result.get("kind", "")) in ["camp", "supply", "shop"]:
		open_requested.emit(&"map_shop" if str(result["kind"]) == "shop" else &"map_camp", {"node": str(_map.get("pos", ""))})

func _fill_cards() -> void:
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	_card_buttons.clear()
	for row in _view.get("hand", []):
		var uid := str(row.get("uid", ""))
		if uid.begins_with("story:") or uid.begins_with("event:") or uid == "big_fate":
			_card_link(uid, Data.text("event_continue" if uid.begins_with("event:") else ("big_fate" if uid == "big_fate" else "story")))
	var battle: Dictionary = _campaign.get("battle2", {})
	if bool(battle.get("has_battle", false)) and not bool(battle.get("resolved", false)):
		_card_link("battle", Data.text("battle"))
	_card_link("squad", Data.text("squad"))
	_card_link("status", Data.text("status"))
	_card_link("inventory", Data.text("inventory"))

func _card_link(uid: String, label: String) -> void:
	if _card_buttons.has(uid):
		return
	var button := Button.new()
	HdTheme.apply_button(button, "ghost")
	button.text = label
	button.set_meta("uid", uid)
	if uid == "inventory":
		button.pressed.connect(func(): open_requested.emit(&"map", {"inventory": true}))
	else:
		button.pressed.connect(func(): card_pressed.emit(uid))
	_cards.add_child(button)
	_card_buttons[uid] = button

func _ensure() -> void:
	if _built:
		return
	_built = true
	var background := ColorRect.new()
	background.color = HdTheme.color("hd_ink")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_title = _label("", Rect2(24, 10, 1080, 30), 23)
	_metrics = _label("", Rect2(24, 43, 1080, 24), 14)
	_button("menu", Data.text("menu"), Rect2(1152, 16, 104, 42), func(): menu_pressed.emit())
	_cards = HBoxContainer.new()
	_cards.position = Vector2(24, 72)
	_cards.size = Vector2(850, 32)
	_cards.add_theme_constant_override("separation", 6)
	add_child(_cards)
	_button("interlude", Data.text("interlude"), Rect2(890, 72, 176, 32), func(): open_requested.emit(&"map_interlude", {"event": str(_map.get("interlude", ""))}))
	_button("center", Data.text("center"), Rect2(1078, 72, 178, 32), func(): _canvas.center_current())
	_canvas = Canvas.new()
	_canvas.position = Vector2(24, 112)
	_canvas.size = Vector2(850, 452)
	_canvas.node_selected.connect(select_node)
	add_child(_canvas)
	_node = NodeCard.new()
	_node.position = Vector2(890, 112)
	_node.size = Vector2(366, 452)
	_node.command_requested.connect(_send)
	_node.card_pressed.connect(func(uid: String): card_pressed.emit(uid))
	add_child(_node)
	var hand_scroll := ScrollContainer.new()
	hand_scroll.position = Vector2(24, 578)
	hand_scroll.size = Vector2(558, 90)
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(hand_scroll)
	_hand = Hand.new()
	_hand.card_requested.connect(func(index: int): _send(&"campaign.map_card", {"index": index}))
	hand_scroll.add_child(_hand)
	_button("roll", Data.text("roll"), Rect2(604, 578, 110, 42), func(): _send(&"campaign.map_roll", {}))
	_steps = SpinBox.new()
	_steps.position = Vector2(724, 578)
	_steps.size = Vector2(70, 42)
	_steps.min_value = 1
	_steps.max_value = 6
	_steps.value = 6
	_steps.add_theme_font_override("font", HdTheme.font("sans"))
	_steps.add_theme_font_size_override("font_size", 16)
	add_child(_steps)
	_button("roll_fixed", Data.text("roll_fixed"), Rect2(840, 578, 140, 42), func(): _send(&"campaign.map_roll", {"steps": int(_steps.value)}))
	_daily = _label("", Rect2(604, 630, 376, 42), 14)
	_daily.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end = _button("end", Data.text("end_day"), Rect2(998, 578, 258, 94), func(): end_pressed.emit())
	_status = _label(Data.text("hint"), Rect2(24, 682, 1232, 28), 14)

func _button(id: String, label: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.name = id
	HdTheme.apply_button(button, "secondary")
	button.add_theme_font_size_override("font_size", 16)
	button.position = rect.position
	button.size = rect.size
	button.text = label
	button.pressed.connect(callback)
	add_child(button)
	_actions[id] = button
	return button

func _label(value: String, rect: Rect2, px: int) -> Label:
	var label := HdTheme.make_label(value, px)
	label.position = rect.position
	label.size = rect.size
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(label)
	return label
