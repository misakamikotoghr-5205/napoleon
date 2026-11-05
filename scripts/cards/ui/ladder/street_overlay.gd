# Street layer: one hint and the redeem button. The scene layer swaps the background.
# Owner C11. Frozen: refresh(view), signal redeem_shop_pressed. Anchor: a.street.redeem.
# Button sits on CardLayout.STREET_REDEEM. The root ignores the mouse; only the button does not.
# TODO(design): teacher for gd.street stays "" (contract §7.10.10 conflict c).
# Reskin 10-22 (prototype 74_street_day): the hint is a small dark note with a gold left rule above the button;
# the button is the gold primary big button (brush 22), like the end-day plate above it.
# Rogue v1: while relics rest on the curio shelf (view.relics dormant, count > 0) a second note above the hint says so
# (the shelf and its drawer are not reachable on the street).
class_name CardStreetOverlay
extends Control

const Ui = preload("res://scripts/cards/ui/ladder/ladder_ui.gd")
const HINT_H := 76.0
const RELICS_H := 56.0

signal redeem_shop_pressed

var _button: Button
var _hint: Label
var _relics: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint = _note("hint", "c11.street.hint", HINT_H)
	_hint.position = CardLayout.STREET_REDEEM.position - Vector2(0, HINT_H + 8)
	_relics = _note("relics_rest", "rg4.relics.away", RELICS_H)
	_relics.position = _hint.position - Vector2(0, RELICS_H + 6)
	_relics.visible = false
	_button = Ui.button(CardText.ui("c11.street.redeem"), CardText.is_draft("c11.street.redeem"))
	_button.name = "redeem"
	_button.theme_type_variation = &"PrimaryBigButton"
	_button.add_theme_font_override("font", CardTheme.font_title())
	_button.add_theme_font_size_override("font_size", 24)
	_button.position = CardLayout.STREET_REDEEM.position
	_button.size = CardLayout.STREET_REDEEM.size
	_button.custom_minimum_size = CardLayout.STREET_REDEEM.size
	_button.pressed.connect(func() -> void: redeem_shop_pressed.emit())
	add_child(_button)
	CardAnchors.register(&"a.street.redeem", _button)
	visible = false


## A small dark note with a gold left rule (the hint, the resting-relics line).
func _note(node_name: String, key: String, h: float) -> Label:
	var l := Label.new()
	l.name = node_name
	l.text = CardText.ui(key)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", CardTheme.font_body())
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", CardTheme.color(&"text_2" if CardText.is_draft(key) else &"hud_ink"))
	var note := CardTheme.row_note_style(&"gold_hi", 3)
	note.bg_color = CardTheme.color(&"flash_bg")
	note.shadow_color = CardTheme.with_alpha(&"scene_void", 0.6)
	note.shadow_size = 8
	note.shadow_offset = Vector2(0, 3)
	l.add_theme_stylebox_override("normal", note)
	l.size = Vector2(CardLayout.STREET_REDEEM.size.x, h)
	l.custom_minimum_size = l.size
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func refresh(view: Dictionary) -> void:
	if _hint != null:
		_hint.text = CardText.ui("c11.street.hint")
	if _relics != null:
		var relics = view.get("relics", {})
		_relics.text = CardText.ui("rg4.relics.away")
		_relics.visible = typeof(relics) == TYPE_DICTIONARY and bool(relics.get("dormant", false)) \
			and int(relics.get("count", 0)) > 0
	if _button != null:
		_button.text = CardText.ui("c11.street.redeem")
	visible = str(view.get("mode", "shop")) == "street"
