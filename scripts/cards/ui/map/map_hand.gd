## One daily march choice: use one card or roll. The model validates every request.
extends HBoxContainer

signal card_requested(index: int)
const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const Data = preload("res://scripts/cards/ui/map/map_data.gd")
var _buttons: Dictionary = {}

func refresh(map: Dictionary, enabled: bool) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_buttons.clear()
	add_theme_constant_override("separation", 8)
	for row in map.get("hand", []):
		var index := int(row.get("index", 0))
		var button := Button.new()
		button.name = "MarchCard%d" % index
		HdTheme.apply_button(button, "secondary")
		button.custom_minimum_size = Vector2(150, 66)
		button.text = Data.card_name(str(row.get("id", "")), str(row.get("label", ""))) + "\n" + Data.text("mp_gain", {"n": int(row.get("mp", 0))})
		button.tooltip_text = Data.card_hint(row)
		button.disabled = not enabled or not bool(map.get("can_roll", false))
		button.pressed.connect(func(): card_requested.emit(index))
		_buttons[index] = button
		add_child(button)

func action_button(index: int) -> Button:
	return _buttons.get(index) as Button
