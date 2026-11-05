# One group on the telegram sheet: four code digits as the post office wrote them (a smudged digit shows both
# of its readings run together under an ink blot, the same whichever one is real), the pencil line under it
# when a key is in use, and the slot where the player's chosen word is copied. Left click = choose this group;
# the small cross on a filled slot (or a right click) = rub the word out. No class_name; preload it. Owner C15.
# Acceptance fix2 (10-25): the blot only ever covers its pair's own window (blot_rects), so a part of each
# reading's own strokes always shows beside it (0/8 used to read as a plain 0), a light stain marks the smudged
# digit at a glance (wash_rects), both the same whichever reading is real; the pairs are a rule of the
# game, listed on the sheet (PAIRS), the same as the engine's confusable digits.
extends Control

const PENCIL_H := 18.0
## Digits a smudge can run together (DESIGN 8.2; the same pairs as CardAppraisal.CONFUSABLE).
const PAIRS: Array = [[1, 7], [2, 7], [3, 8], [0, 8], [4, 9], [5, 6]]
const BLOT_ALPHA := 0.85
const FAINT_ALPHA := 0.62
const WASH_ALPHA := 0.16

var game = null
var index: int = 0
var digits: Array = []          # shown digits (0-9)
var smudge_at: int = -1         # digit position under a blot, or -1
var smudge_pair: Array = []     # the two digits a smudged position can be
var crib: bool = false          # the key group: no slot
var pencil: bool = false
var pencil_digits: Array = []   # digits after the key is taken off (-1 under the blot)
var filled: bool = false
var selected: bool = false
var compact: bool = false
var blot_seed: Array = []       # small blot squares [x, y] in 0..1 of the digit box

var _word: Label = null
var _minus: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func build() -> void:
	_word = Label.new()
	_word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_word.add_theme_font_override("font", CardTheme.font_body())
	_word.add_theme_font_size_override("font_size", 16 if compact else 20)
	_word.add_theme_color_override("font_color", CardTheme.color(&"ink"))
	_word.clip_text = true
	_word.position = Vector2(10, slot_y() - (22.0 if compact else 28.0))
	_word.size = Vector2(size.x - 34.0, 26.0 if compact else 30.0)
	add_child(_word)
	_minus = Label.new()
	_minus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minus.add_theme_font_override("font", CardTheme.font_body())
	_minus.add_theme_font_size_override("font_size", 14)
	_minus.add_theme_color_override("font_color", CardTheme.color(&"ink_3"))
	_minus.position = Vector2(10, pencil_y())
	_minus.size = Vector2(size.x * 0.5, PENCIL_H)
	_minus.visible = false
	add_child(_minus)


func set_word(text: String) -> void:
	filled = text != ""
	if _word != null:
		_word.text = text
	queue_redraw()


func set_pencil(on: bool, minus_text: String, ds: Array) -> void:
	pencil = on and not crib
	pencil_digits = ds.duplicate()
	if _minus != null:
		_minus.visible = pencil
		_minus.text = minus_text if pencil else ""
	queue_redraw()


func digit_size() -> int:
	return 24 if compact else 30


func slot_y() -> float:
	return size.y - 10.0


func pencil_y() -> float:
	return float(digit_size()) + 12.0


func clear_rect() -> Rect2:
	return Rect2(size.x - 22.0, slot_y() - 18.0, 16.0, 16.0)


func _gui_input(event: InputEvent) -> void:
	if game == null or game.is_done() or not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if filled and not crib and clear_rect().grow(4.0).has_point(mb.position):
			game.apply_op(["clear", index])
		elif not crib:
			game.apply_op(["select", index])
		accept_event()
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		if filled and not crib:
			game.apply_op(["clear", index])
		accept_event()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if selected:
		draw_rect(r, CardTheme.with_alpha(&"gold_pale", 0.45))
		draw_rect(r.grow(-1.0), CardTheme.color(&"gold_hi"), false, 2.0)
	else:
		draw_rect(r.grow(-1.0), CardTheme.with_alpha(&"ink_3", 0.5), false, 1.0)
	var font := CardTheme.font_body()
	var fs := digit_size()
	var box := float(fs)
	var ink := CardTheme.color(&"ink")
	for d in range(digits.size()):
		var at := digit_at(d)
		if d == smudge_at and smudge_pair.size() == 2:
			var wash := CardTheme.with_alpha(&"ink", WASH_ALPHA)
			for wr in wash_rects():
				draw_rect(wr, wash)
			var faint := CardTheme.with_alpha(&"ink", FAINT_ALPHA)
			_digit(font, fs, at, box, int(smudge_pair[0]), faint)
			_digit(font, fs, at, box, int(smudge_pair[1]), faint)
			var c := CardTheme.with_alpha(&"ink", BLOT_ALPHA)
			for br in blot_rects():
				draw_rect(br, c)
		else:
			_digit(font, fs, at, box, int(digits[d]), ink)
	if pencil:
		var px := size.x * 0.5
		var pc := CardTheme.color(&"ink_3")
		for d in range(pencil_digits.size()):
			var v := int(pencil_digits[d])
			var at2 := Vector2(px + float(d) * 12.0, pencil_y())
			if v < 0:
				draw_rect(Rect2(at2 + Vector2(2, 4), Vector2(8, 10)), CardTheme.with_alpha(&"ink_3", 0.7))
			else:
				draw_string(font, at2 + Vector2(0, 14), str(v), HORIZONTAL_ALIGNMENT_CENTER, 12.0, 14, pc)
	if crib:
		return
	var line := CardTheme.color(&"ink_3")
	draw_line(Vector2(8, slot_y()), Vector2(size.x - 28.0, slot_y()), line, 1.0)
	if filled:
		var c := clear_rect()
		draw_line(c.position + Vector2(3, 3), c.end - Vector2(3, 3), line, 2.0)
		draw_line(Vector2(c.end.x - 3, c.position.y + 3), Vector2(c.position.x + 3, c.end.y - 3), line, 2.0)


func _digit(font: Font, fs: int, at: Vector2, box: float, v: int, c: Color) -> void:
	draw_string(font, at + Vector2(0, float(fs) * 0.95), str(v), HORIZONTAL_ALIGNMENT_CENTER, box, fs, c)


## Top-left of digit d's box (the digit is drawn centred in a box digit_size() wide).
func digit_at(d: int) -> Vector2:
	return Vector2(10.0 + float(d) * float(digit_size()), 6.0)


## Where the ink spread (the "yin" of a smudge): a light stain over the whole smudged digit, drawn under its two
## readings, so the smudged place stands out from the clean digits at a glance. Same for both readings.
func wash_rects() -> Array:
	var out: Array = []
	if smudge_at < 0 or smudge_pair.size() != 2:
		return out
	var at := digit_at(smudge_at)
	var box := float(digit_size())
	var core := Rect2((at + Vector2(box * 0.14, box * 0.14)).floor(), Vector2(box * 0.72, box * 0.88).floor())
	out.append(core)
	var sq := roundf(box * 0.3)
	for b in blot_seed:
		var p := Vector2(clampf(float(b[0]), 0.0, 1.0), clampf(float(b[1]), 0.0, 1.0))
		out.append(Rect2((core.position - Vector2(sq, sq) * 0.5 + p * core.size).floor(), Vector2(sq, sq)))
	return out


## The blot over the smudged digit, in this slip's coordinates: a core and a few squares from blot_seed (the
## same for both readings), all inside the pair's window (_mask_rect), so it never hides more than that window.
func blot_rects() -> Array:
	var out: Array = []
	if smudge_at < 0 or smudge_pair.size() != 2:
		return out
	var box := float(digit_size())
	var area := blot_window()
	var sq := minf(maxf(4.0, roundf(box * 0.2)), minf(area.size.x, area.size.y))
	var inset := floorf(sq * 0.25)
	out.append(area.grow(-inset))
	for b in blot_seed:
		var p := Vector2(clampf(float(b[0]), 0.0, 1.0), clampf(float(b[1]), 0.0, 1.0))
		out.append(Rect2((area.position + p * (area.size - Vector2(sq, sq))).floor(), Vector2(sq, sq)))
	return out


## The pair's window on the smudged digit, in this slip's coordinates (whole pixels); empty without a smudge.
func blot_window() -> Rect2:
	if smudge_at < 0 or smudge_pair.size() != 2:
		return Rect2()
	var at := digit_at(smudge_at)
	var box := float(digit_size())
	var glyph := Rect2(at.x + box * 0.16, at.y + box * 0.2, box * 0.68, box * 0.78)
	var m := _mask_rect(smudge_pair)
	var area := Rect2(glyph.position + m.position * glyph.size, m.size * glyph.size)
	return Rect2(area.position.floor(), area.size.floor())


## The window the blot may cover for a pair, in 0..1 of the digit's glyph box: over part of where the two
## readings differ, leaving some of each reading's own strokes in sight (pinned by C15_decode_eye).
static func _mask_rect(pair: Array) -> Rect2:
	if pair.size() != 2:
		return Rect2(0.1, 0.25, 0.8, 0.5)
	var lo := mini(int(pair[0]), int(pair[1]))
	var hi := maxi(int(pair[0]), int(pair[1]))
	match lo * 10 + hi:
		38:
			return Rect2(0.0, 0.36, 0.5, 0.28)
		17:
			return Rect2(0.0, 0.0, 1.0, 0.4)
		49:
			return Rect2(0.0, 0.0, 1.0, 0.45)
		56:
			return Rect2(0.0, 0.5, 0.5, 0.5)
		8:
			return Rect2(0.0, 0.34, 0.5, 0.32)
		27:
			return Rect2(0.0, 0.58, 1.0, 0.42)
	return Rect2(0.1, 0.25, 0.8, 0.5)


## True when the pair has its own window (every pair in PAIRS does).
static func has_own_mask(pair: Array) -> bool:
	return _mask_rect(pair) != _mask_rect([])
