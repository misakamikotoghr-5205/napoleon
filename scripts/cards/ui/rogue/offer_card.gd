# One card on the stocktake overlay (288 x 400): depth word, picture, name, a few lines of history, what it does
# for the shop and its flaw (relics) or how long it lasts (sources), and the take button. No numbers, no stars:
# depth shows only as the frame colour and two or three words. No class_name (preload).
# Layout (section 7.2, card space): tag 10-30, picture 36-164, name 172-196, button 356-392. The words between
# 200 and 352 are laid out from the bottom up so what the thing does is never cut off: the flaw (or "until the
# month ends" for a source) sits right above the button, the use above it, each as many lines as its words need
# (at most 3 / 4), and the history takes the 1-4 lines left above them (ellipsis when it runs over); only then does
# hovering the card show the whole history, wrapped to the card's width (the relics drawer prints it in full too).
# A history the card already prints whole has no tooltip (acceptance 6: it only covered the next card).
# Owner RG4. Contract: docs/cards/rogue/ROGUE_V1.md sections 7.2, 11.
extends Control

const Ui = preload("res://scripts/cards/ui/rogue/rogue_ui.gd")

signal take_pressed(index: int)
signal face_pressed(index: int)

const SIZE := Vector2(288, 400)
const PAD := 18.0
const TAG_Y := 10.0
const PIC_Y := 36.0
const PIC_H := 128.0
const NAME_Y := 172.0
const BODY_Y := 200.0
const TEXT_BOTTOM := 352.0
const TEXT_SIZE := 14
const MAX_BODY := 4
const MAX_USE := 4
const MAX_FLAW := 3
const UNTIL_H := 24.0
const ROW_GAP := 5.0
const BTN_Y := 356.0
const BTN_H := 36.0
const MARK_W := 44.0

var index: int = -1
var item_id: String = ""
var kind: String = ""
var look: String = "plain"
var _face: Panel
var _button: Button
var _selected: bool = false


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_PASS


## item: {id, kind: relic|source, art, depth}.
func setup(item: Dictionary, at: int) -> void:
	index = at
	item_id = str(item.get("id", ""))
	kind = "source" if str(item.get("kind", "")) == "source" else "relic"
	look = Ui.look_of(kind, str(item.get("depth", "")))
	name = "Offer%d" % at
	set_meta("item", item_id)
	set_meta("kind", kind)
	_face = Panel.new()
	_face.name = "Face"
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.size = SIZE
	add_child(_face)
	_paint()
	_tag()
	_picture(str(item.get("art", "")))
	_words()
	_take_button()


func button() -> Button:
	return _button


func is_selected() -> bool:
	return _selected


## Keyboard pick (1-3): gold edge.
func set_selected(on: bool) -> void:
	_selected = on
	_paint()


## While the overlay waits for something else (the release step, a closed offer) the take button rests.
func set_locked(on: bool) -> void:
	if _button != null:
		_button.disabled = on


func set_dim(on: bool) -> void:
	modulate = Color(1, 1, 1, 0.45) if on else Color.WHITE


## A click on the card face (not on its button) picks the card, like the 1-3 keys.
func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		face_pressed.emit(index)
		accept_event()


func _paint() -> void:
	if _face != null:
		_face.add_theme_stylebox_override("panel", Ui.card_style(look, _selected))


func _tag() -> void:
	var key := Ui.depth_word_key(look)
	var tag := Ui.pill(CardText.ui(key), Ui.frame_key(look), Ui.PILL_INKS.get(look, &"paper"), 14, CardText.is_draft(key))
	tag.name = "Depth"
	tag.position = Vector2(PAD - 4.0, TAG_Y)
	tag.custom_minimum_size = Vector2(0, 20)
	add_child(tag)


func _picture(art_id: String) -> void:
	var well := Panel.new()
	well.name = "Well"
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.position = Vector2(PAD, PIC_Y)
	well.size = Vector2(SIZE.x - PAD * 2.0, PIC_H)
	well.add_theme_stylebox_override("panel", Ui.well_style())
	add_child(well)
	# Relics 32x32 x4 = 128; source pictures 64x48 x2 = 128x96; both centred in the well, nearest filter.
	var base := Ui.base_of(art_id, look)
	var k := maxf(1.0, floorf(minf(PIC_H / base.y, (SIZE.x - PAD * 2.0) / base.x)))
	var box := base * k
	var pic := Ui.art(art_id, box)
	pic.name = "Picture"
	pic.position = Vector2((SIZE.x - box.x) * 0.5, PIC_Y + (PIC_H - box.y) * 0.5)
	add_child(pic)


func _words() -> void:
	var inner := SIZE.x - PAD * 2.0
	var title := Ui.label(Ui.card_text(item_id, "title"), CardTheme.font_size(&"card"), &"ink", &"title",
		Ui.is_draft(item_id, "title"))
	title.name = "Name"
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(PAD, NAME_Y - 2.0)
	title.size = Vector2(inner, 26)
	add_child(title)
	var y := TEXT_BOTTOM
	if kind == "source":
		y -= UNTIL_H
		var until := Ui.label(CardText.ui("rg4.stock.source_until"), 14, &"ink_soft", &"bold",
			CardText.is_draft("rg4.stock.source_until"))
		until.name = "Until"
		until.position = Vector2(PAD, y)
		until.size = Vector2(inner, UNTIL_H)
		add_child(until)
		y -= ROW_GAP
	elif CardText.has_text(item_id + "#lines.flaw"):
		y = _marked_line("Flaw", "rg4.stock.flaw", &"seal_dark", Ui.card_text(item_id, "lines.flaw"), false, y, MAX_FLAW)
		y -= ROW_GAP
	y = _marked_line("Use", "rg4.stock.use", &"ledger_in", Ui.card_text(item_id, "use"), Ui.is_draft(item_id, "use"),
		y, MAX_USE)
	y -= ROW_GAP
	var pitch := Ui.text_height(2, TEXT_SIZE) - Ui.text_height(1, TEXT_SIZE)
	var room := clampi(1 + int(floorf((y - BODY_Y - Ui.text_height(1, TEXT_SIZE)) / pitch)), 1, MAX_BODY)
	var body := Ui.block(Ui.card_text(item_id, "body"), TEXT_SIZE, &"card_sub_ink",
		Vector2(inner, Ui.text_height(room, TEXT_SIZE)), room, Ui.is_draft(item_id, "body"))
	body.name = "Body"
	body.position = Vector2(PAD, BODY_Y)
	# Very long use and flaw words together leave no line for the history: it steps aside rather than overlap.
	body.visible = y - BODY_Y >= Ui.text_height(1, TEXT_SIZE)
	add_child(body)
	var full := Ui.card_text(item_id, "body")
	var cut := not body.visible or Ui.lines_of(full, inner, TEXT_SIZE) > room
	tooltip_text = full if cut else ""


## The cut history on hover, wrapped to the card's width so it does not run across the neighbouring card.
func _make_custom_tooltip(for_text: String) -> Object:
	if for_text == "":
		return null
	var l := Label.new()
	l.theme_type_variation = &"TooltipLabel"
	l.text = for_text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(SIZE.x, 0)
	return l


## A small coloured mark ("use" / "flaw") and the words next to it, as many lines as they need (at most max_lines),
## ending at bottom. Returns the top of the row.
func _marked_line(node_name: String, mark_key: String, mark_bg: StringName, text: String, draft: bool, bottom: float,
		max_lines: int) -> float:
	var width := SIZE.x - PAD * 2.0 - MARK_W
	var n := mini(Ui.lines_of(text, width, TEXT_SIZE), max_lines)
	var h := Ui.text_height(n, TEXT_SIZE)
	var top := bottom - h
	var mark := Ui.pill(CardText.ui(mark_key), mark_bg, &"paper", 14, CardText.is_draft(mark_key))
	mark.name = node_name + "Mark"
	mark.position = Vector2(PAD, top + 1.0)
	add_child(mark)
	var words := Ui.block(text, TEXT_SIZE, &"ink", Vector2(width, h), n, draft)
	words.name = node_name
	words.position = Vector2(PAD + MARK_W, top)
	add_child(words)
	return top


func _take_button() -> void:
	var key := "rg4.stock.take_source" if kind == "source" else "rg4.stock.take_relic"
	_button = Button.new()
	_button.name = "Take"
	_button.text = CardText.ui(key)
	_button.theme_type_variation = &"PrimaryButton"
	_button.focus_mode = Control.FOCUS_ALL
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_button.position = Vector2(PAD + 12.0, BTN_Y)
	_button.size = Vector2(SIZE.x - (PAD + 12.0) * 2.0, BTN_H)
	_button.pressed.connect(func() -> void: take_pressed.emit(index))
	add_child(_button)
