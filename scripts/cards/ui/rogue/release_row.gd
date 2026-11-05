# The stocktake overlay's release step (section 7.2, "full: give one up"): the shelf is full and the player
# picked a relic, so the bottom of the sheet asks which held relic goes back to the storeroom. One 64x64 cell per
# held relic (32x32 art x2), the picked one's name and depth word, "give it up, put the new one up" and
# "never mind". Sends nothing itself; the overlay sends stock.pick with replace. No class_name (preload).
# Sheet space (the overlay's 1100 x 640): this row sits at y 512 and is 1100 x 128.
# Owner RG4. Contract: docs/cards/rogue/ROGUE_V1.md sections 7.2, 11.
extends Control

const Ui = preload("res://scripts/cards/ui/rogue/rogue_ui.gd")

signal chosen(index: int)
signal confirmed
signal cancelled

const SIZE := Vector2(1100, 128)
const HINT_AT := Vector2(40, 0)
const CELLS_X := 328.0
const CELLS_Y := 28.0
const CELL := 64.0
const CELL_GAP := 12.0
const NAME_AT := Vector2(40, 34)
const NAME_W := 276.0
## Both buttons 40 high (the theme's minimum), the lower one ending above the sheet's inner gold frame.
const OK_AT := Vector2(810, 28)
const OK_SIZE := Vector2(220, 40)
const CANCEL_AT := Vector2(810, 72)
const CANCEL_SIZE := Vector2(220, 40)
const MAX_CELLS := 6

var held: Array = []
var _cells: Array[Button] = []
var _picked: int = -1
var _name: Label
var _depth: Label
var _ok: Button
var _cancel: Button


func _init() -> void:
	name = "Release"
	size = SIZE
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS


## rows: the stocktake answer's held list [{id, art, depth}], oldest first.
func setup(rows: Array) -> void:
	held = []
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY and str(row.get("id", "")) != "":
			held.append(row)
	var hint := Ui.label(CardText.ui("rg4.stock.full"), 16, &"hud_ink", &"body", CardText.is_draft("rg4.stock.full"))
	hint.name = "Hint"
	hint.position = HINT_AT
	hint.size = Vector2(1020, 24)
	hint.clip_text = true
	add_child(hint)
	for i in range(mini(held.size(), MAX_CELLS)):
		_cells.append(_cell(i, held[i]))
	_name = Ui.line("", 18, &"gold_hi", NAME_W)
	_name.name = "PickedName"
	_name.add_theme_font_override("font", CardTheme.font_title())
	_name.position = NAME_AT
	_name.size = Vector2(NAME_W, 26)
	add_child(_name)
	_depth = Ui.line("", 14, &"text_2", NAME_W)
	_depth.name = "PickedDepth"
	_depth.position = NAME_AT + Vector2(0, 30)
	_depth.size = Vector2(NAME_W, 22)
	add_child(_depth)
	_ok = _button("ReplaceOk", "rg4.stock.replace_ok", &"PrimaryButton", OK_AT, OK_SIZE)
	_ok.disabled = true
	_ok.pressed.connect(func() -> void: confirmed.emit())
	_cancel = _button("ReplaceCancel", "rg4.stock.replace_cancel", &"", CANCEL_AT, CANCEL_SIZE)
	_cancel.pressed.connect(func() -> void: cancelled.emit())


func picked() -> int:
	return _picked


func picked_id() -> String:
	return str(held[_picked].get("id", "")) if _picked >= 0 and _picked < held.size() else ""


func cell(i: int) -> Button:
	return _cells[i] if i >= 0 and i < _cells.size() else null


func ok_button() -> Button:
	return _ok


func cancel_button() -> Button:
	return _cancel


## Keys 1-6 and clicks land here: mark the cell, name it, allow the confirm button.
func pick(i: int) -> void:
	if i < 0 or i >= _cells.size():
		return
	_picked = i
	for j in _cells.size():
		_cells[j].add_theme_stylebox_override("normal", _cell_style(j == i))
		_cells[j].add_theme_stylebox_override("hover", _cell_style(true))
	var id := picked_id()
	_name.text = Ui.card_text(id, "title")
	var look := Ui.look_of("relic", str(held[i].get("depth", "")))
	_depth.text = CardText.ui(Ui.depth_word_key(look))
	_ok.disabled = false
	_cells[i].grab_focus()
	chosen.emit(i)


func _cell(i: int, row: Dictionary) -> Button:
	var b := Button.new()
	b.name = "Held%d" % i
	b.position = Vector2(CELLS_X + float(i) * (CELL + CELL_GAP), CELLS_Y)
	b.size = Vector2(CELL, CELL)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = _words(str(row.get("id", "")), str(row.get("depth", "")))
	b.set_meta("item", str(row.get("id", "")))
	for s in [&"normal", &"pressed", &"disabled"]:
		b.add_theme_stylebox_override(s, _cell_style(false))
	for s in [&"hover", &"hover_pressed"]:
		b.add_theme_stylebox_override(s, _cell_style(true))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var pic := Ui.art(str(row.get("art", "")), Vector2(CELL, CELL))
	pic.name = "Picture"
	b.add_child(pic)
	b.pressed.connect(pick.bind(i))
	add_child(b)
	return b


## Hover words for a held relic: name and depth word, then what it does and its flaw (the drawer's row, in short).
func _words(id: String, depth: String) -> String:
	var word := CardText.ui(Ui.depth_word_key(Ui.look_of("relic", depth)))
	var lines := PackedStringArray([Ui.card_text(id, "title") + "  " + word])
	lines.append(CardText.ui("rg4.stock.use") + "  " + Ui.card_text(id, "use"))
	if CardText.has_text(id + "#lines.flaw"):
		lines.append(CardText.ui("rg4.stock.flaw") + "  " + Ui.card_text(id, "lines.flaw"))
	return "\n".join(lines)


func _cell_style(on: bool) -> StyleBoxFlat:
	var sb := CardTheme.flat_style(&"wood_1", &"gold_hi" if on else &"line", 3 if on else 1, 4, 0.0, 0.0)
	if on:
		sb.shadow_color = CardTheme.with_alpha(&"gold_glow", 0.5)
		sb.shadow_size = 8
	return sb


func _button(node_name: String, key: String, variation: StringName, at: Vector2, box: Vector2) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = CardText.ui(key)
	b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.position = at
	b.size = box
	add_child(b)
	return b
