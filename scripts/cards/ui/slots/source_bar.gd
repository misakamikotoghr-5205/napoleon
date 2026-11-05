# 不拖也能放：你自己、人脉、留着的牌、物品、消息，以及钱的加减。主人 C03。不写 class_name。
# 合同：docs/cards/CARDS_INTERFACES.md §3.3 C03、§7.4、§7.5。used_today / away_days 时人灰掉。
extends VBoxContainer

signal picked(source: Dictionary)

const Chip = preload("res://scripts/cards/ui/slots/drag_chip.gd")
const Ui = preload("res://scripts/cards/ui/slots/slot_ui.gd")

var _amount: int = 20
var _money_box: HBoxContainer
var _amount_label: Label
var _money_chip = null
var _self_btn: Button
var _rows: Container


func _init() -> void:
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_money_box = HBoxContainer.new()
	_money_box.name = "MoneyBox"
	_money_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_money_box.add_theme_constant_override("separation", 6)
	Ui.pin(_money_box, Vector2(420, 36))
	add_child(_money_box)
	var minus := Ui.button(CardText.ui("c03.picker.minus"))
	minus.name = "Minus"
	minus.pressed.connect(_add_amount.bind(-10))
	_money_box.add_child(minus)
	_amount_label = Ui.num_label(_amount)
	_amount_label.name = "MoneyAmount"
	_money_box.add_child(_amount_label)
	var plus := Ui.button(CardText.ui("c03.picker.plus"))
	plus.name = "Plus"
	plus.pressed.connect(_add_amount.bind(10))
	_money_box.add_child(plus)
	_money_chip = _chip(CardText.ui("c03.picker.money"), {"kind": "money", "amount": _amount}, "PickMoney")
	_money_chip.pressed.connect(place_money)
	_money_box.add_child(_money_chip)
	_rows = HFlowContainer.new()
	_rows.name = "Sources"
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_theme_constant_override("h_separation", 6)
	_rows.add_theme_constant_override("v_separation", 6)
	Ui.pin(_rows, Vector2(700, 36))
	add_child(_rows)


func money_anchor() -> Control:
	return _money_box


func set_amount(n: int) -> void:
	_amount = maxi(0, n)
	if _amount_label != null:
		_amount_label.text = str(_amount)
	if _money_chip != null:
		_money_chip.payload = {"kind": "money", "amount": _amount}


func amount() -> int:
	return _amount


func place_self() -> bool:
	if _self_btn == null or _self_btn.disabled:
		return false
	picked.emit({"kind": "self"})
	return true


func place_money() -> void:
	picked.emit({"kind": "money", "amount": _amount})


func refresh(view: Dictionary, items: Array) -> void:
	_self_btn = null
	Ui.clear(_rows)
	_add_self(view.get("self", {}) if typeof(view.get("self")) == TYPE_DICTIONARY else {})
	_add_cards(view.get("contacts", []), "contact", "c03.picker.contact")
	_add_cards(view.get("kept", []), "kept", "c03.picker.kept")
	_add_items(items)
	_add_news(view.get("hand", []))
	set_amount(_amount)


func _add_amount(delta: int) -> void:
	set_amount(_amount + delta)


func _add_self(self_view: Dictionary) -> void:
	if self_view.is_empty():
		return
	var title := CardText.card(str(self_view.get("def", "")), "title")
	if str(self_view.get("def", "")) == "":
		title = CardText.ui("c03.picker.self")
	var chip := _chip(title, {"kind": "self"}, "PickSelf")
	chip.disabled = bool(self_view.get("used_today", false))
	_fade(chip)
	chip.pressed.connect(place_self)
	_rows.add_child(chip)
	_self_btn = chip
	if chip.disabled:
		_rows.add_child(_note("c03.picker.used"))


func _add_cards(rows: Variant, kind: String, key: String) -> void:
	if typeof(rows) != TYPE_ARRAY:
		return
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var uid := str(row.get("uid", ""))
		var chip := _chip(_card_title(row, key), {"kind": kind, "uid": uid}, "Pick_%s_%s" % [kind, uid])
		var away := int(row.get("away_days", 0)) > 0
		chip.disabled = kind == "contact" and (bool(row.get("used_today", false)) or away)
		_fade(chip)
		chip.pressed.connect(_emit_chip.bind(chip))
		_rows.add_child(chip)
		if chip.disabled:
			_rows.add_child(_note("c03.picker.away" if away else "c03.picker.used"))


func _add_items(items: Array) -> void:
	for row in items:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var item_id := str(row.get("item", ""))
		var chip := _chip(CardText.ui("c03.picker.item"), {"kind": "item", "item": item_id}, "PickItem_" + item_id)
		chip.pressed.connect(_emit_chip.bind(chip))
		_rows.add_child(chip)


func _add_news(hand: Variant) -> void:
	if typeof(hand) != TYPE_ARRAY:
		return
	for row in hand:
		if typeof(row) != TYPE_DICTIONARY or str(row.get("type", "")) != "news":
			continue
		var uid := str(row.get("uid", ""))
		var chip := _chip(_card_title(row, "c03.picker.news"), {"kind": "news", "uid": uid}, "Pick_news_" + uid)
		chip.pressed.connect(_emit_chip.bind(chip))
		_rows.add_child(chip)


func _card_title(row: Dictionary, fallback: String) -> String:
	var def_id := str(row.get("def", ""))
	if def_id == "":
		return CardText.ui(fallback)
	return CardText.card(def_id, "title")


func _chip(text: String, payload: Dictionary, node_name: String) -> Button:
	var chip = Chip.new()
	chip.text = text
	chip.payload = payload.duplicate(true)
	chip.name = node_name
	chip.clip_text = true
	chip.focus_mode = Control.FOCUS_ALL
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	chip.custom_minimum_size = Vector2(112, 32)
	chip.add_theme_font_override("font", CardTheme.font_body())
	chip.add_theme_font_size_override("font_size", 14)
	chip.add_theme_color_override("font_color", CardTheme.color(&"ink"))
	chip.add_theme_color_override("font_disabled_color", CardTheme.color(&"ink_soft"))
	return chip


func _note(key: String) -> Label:
	return Ui.label(CardText.ui(key), 14, CardText.is_draft(key))


func _fade(chip: Button) -> void:
	chip.modulate = Color(1, 1, 1, 0.45) if chip.disabled else Color.WHITE


func _emit_chip(chip) -> void:
	if chip.disabled:
		return
	picked.emit((chip.payload as Dictionary).duplicate(true))
