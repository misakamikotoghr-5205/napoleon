# Character reading: the stall lays out characters; the player picks one.
# No class_name. The panel sends fortune.cezi. Owner C07.
extends Control

signal picked(char_id: String)

const Style = preload("res://scripts/cards/ui/fortune/fortune_style.gd")

var buttons: Array = []
var _reading: Label
var _prompt: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(730, 220)
	custom_minimum_size = size
	_prompt = Style.label("", 16, true)
	_prompt.position = Vector2.ZERO
	_prompt.size = Vector2(730, 28)
	add_child(_prompt)
	_reading = Style.label("", 18, true)
	_reading.name = "Reading"
	_reading.position = Vector2(0, 140)
	_reading.size = Vector2(730, 72)
	_reading.visible = false
	add_child(_reading)


func show_offer(ids: Array) -> void:
	for b in buttons:
		if is_instance_valid(b):
			b.queue_free()
	buttons = []
	var prompt := CardText.ui("c07.cezi.pick")
	Style.set_label(_prompt, prompt, 16, CardText.is_draft("c07.cezi.pick"))
	_reading.visible = false
	Style.set_label(_reading, "", 18, true)
	var x := 0.0
	for id in ids:
		var cid := str(id)
		var word := CardText.card(cid, "char")
		var b := Style.button(word)
		b.set_meta("char_id", cid)
		b.position = Vector2(x, 36)
		b.size = Vector2(112, 88)
		b.pressed.connect(_emit_pick.bind(cid))
		_add_char_art(b)
		add_child(b)
		buttons.append(b)
		x += 120.0
	size = Vector2(maxf(730.0, x), 220)
	custom_minimum_size = size


func pick_at(i: int) -> void:
	if i < 0 or i >= buttons.size():
		return
	var b: Button = buttons[i]
	if is_instance_valid(b) and not b.disabled:
		b.pressed.emit()


func show_reading(char_id: String, reading: String) -> void:
	for b in buttons:
		if is_instance_valid(b):
			b.visible = false
	var key := char_id + "#" + reading
	var text := CardText.card(char_id, reading)
	Style.set_label(_reading, text, 18, CardText.is_draft(key))
	_reading.visible = true


func _emit_pick(id: String) -> void:
	picked.emit(id)


func _add_char_art(b: Button) -> void:
	var tex := CardArt.texture(Style.ART_CHAR)
	if tex == null:
		return
	var icon := TextureRect.new()
	icon.texture = tex
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(4, 4)
	icon.size = Vector2(28, 36)
	b.add_child(icon)
