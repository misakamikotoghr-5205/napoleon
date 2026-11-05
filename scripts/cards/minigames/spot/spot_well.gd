# Spot the difference: one picture well (the item, or the pattern book) at x6, with the player's pins,
# the hovered pixel and the lens. Everything drawn here is the player's own: pins are one colour
# (gold_hi) whatever they say and wherever they sit. Owner C12. No class_name; preload it.
extends Control

const SCALE := 6
const VIEW := 64 * SCALE
const ZOOM := 12.0            # lens: 1 item pixel = 12 screen pixels (x2 over the well)
const PIN_R := 10.0

signal hovered(img_pos: Vector2, inside: bool)
signal clicked(px: Vector2i, button: int)

var show_pins := false        # the item well shows pins; the book does not
var lens_px := 72.0
var mode := "eye"          # "eye" or "lens"
var pins: Array = []          # [[x, y, tag], ...]
var pending := Vector2i(-1, -1)
var selected := -1
var cursor := Vector2(32, 32)
var cursor_on := false
var lens_on := true           # the book well shows its lens only while the book is open
var short_wear := ""
var short_differs := ""

var _picture: TextureRect
var _overlay: Control
var _lens_tex: Texture2D


func setup(picture: Texture2D, lens_tex: Texture2D) -> void:
	size = Vector2(VIEW, VIEW)
	custom_minimum_size = Vector2(VIEW, VIEW)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture = TextureRect.new()
	_picture.name = "Picture"
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.size = Vector2(VIEW, VIEW)
	_picture.texture = picture
	add_child(_picture)
	_lens_tex = lens_tex
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.size = Vector2(VIEW, VIEW)
	_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.mouse_default_cursor_shape = Control.CURSOR_CROSS
	_overlay.gui_input.connect(_on_input)
	_overlay.mouse_exited.connect(func() -> void: hovered.emit(cursor, false))
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


func set_pictures(picture: Texture2D, lens_tex: Texture2D) -> void:
	if _picture != null and _picture.texture != picture:
		_picture.texture = picture
	_lens_tex = lens_tex
	redraw()


func redraw() -> void:
	if _overlay != null:
		_overlay.queue_redraw()


## Screen-local centre of item pixel p.
static func pixel_center(p: Vector2i) -> Vector2:
	return (Vector2(p) + Vector2(0.5, 0.5)) * float(SCALE)


static func to_img(local: Vector2) -> Vector2:
	return local / float(SCALE)


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hovered.emit(to_img((event as InputEventMouseMotion).position), true)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
			return
		var p := to_img(mb.position)
		hovered.emit(p, true)
		clicked.emit(Vector2i(clampi(int(floor(p.x)), 0, 63), clampi(int(floor(p.y)), 0, 63)), mb.button_index)


func _draw_overlay() -> void:
	var at := cursor * float(SCALE)
	var hover := Vector2i(clampi(int(floor(cursor.x)), 0, 63), clampi(int(floor(cursor.y)), 0, 63))
	if show_pins:
		for i in pins.size():
			_draw_pin(i, false)
		if pending.x >= 0:
			_draw_ring(pixel_center(pending), PIN_R, true)
	if not cursor_on and pending.x < 0 and selected < 0:
		return
	if mode == "lens" and lens_on:
		_draw_lens(at, hover)
	elif not (show_pins and (pending.x >= 0 or selected >= 0)):
		var r := Rect2(Vector2(hover) * float(SCALE), Vector2(SCALE, SCALE))
		_overlay.draw_rect(r.grow(1.0), CardTheme.color(&"wood_0"), false, 1.0)
		_overlay.draw_rect(r, CardTheme.color(&"gold_pale"), false, 1.0)


func _draw_pin(i: int, in_lens: bool) -> void:
	var p: Array = pins[i]
	var c := pixel_center(Vector2i(int(p[0]), int(p[1])))
	_draw_ring(c, PIN_R, false, i == selected)
	if in_lens:
		return
	var font := CardTheme.font_body()
	var label := "%d%s" % [i + 1, short_wear if int(p[2]) == 1 else short_differs]
	var fs := 14
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 8.0
	var box := Rect2(c + Vector2(PIN_R - 2.0, -PIN_R - 16.0), Vector2(w, 18))
	if box.end.x > float(VIEW) - 2.0:
		box.position.x = c.x - PIN_R + 2.0 - w
	if box.position.y < 2.0:
		box.position.y = c.y + PIN_R - 2.0
	_overlay.draw_rect(box, CardTheme.with_alpha(&"wood_0", 0.88), true)
	_overlay.draw_rect(box, CardTheme.color(&"gold_hi"), false, 1.0)
	_overlay.draw_string(font, box.position + Vector2(4, 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		CardTheme.color(&"gold_hi"))


## A pin ring: dark halo, gold ring; the pending one is a dotted pale ring; the selected one has a second ring.
func _draw_ring(c: Vector2, r: float, dotted: bool, chosen: bool = false) -> void:
	var dark := CardTheme.with_alpha(&"wood_0", 0.85)
	if dotted:
		_overlay.draw_arc(c, r, 0.0, TAU, 32, dark, 4.0, true)
		for k in 12:
			var a0 := TAU * float(k) / 12.0
			_overlay.draw_arc(c, r, a0, a0 + TAU / 24.0, 4, CardTheme.color(&"gold_pale"), 2.0, true)
		return
	_overlay.draw_arc(c, r, 0.0, TAU, 32, dark, 5.0, true)
	_overlay.draw_arc(c, r, 0.0, TAU, 32, CardTheme.color(&"gold_hi"), 2.0, true)
	if chosen:
		_overlay.draw_arc(c, r + 4.0, 0.0, TAU, 32, CardTheme.color(&"gold_pale"), 1.0, true)


## The lens: a circle of radius lens_px at x2 over the well, clipped by the well. Pins show as rings at
## their magnified place; a small cross marks the pixel a click would pin.
func _draw_lens(center: Vector2, hover: Vector2i) -> void:
	if _lens_tex == null:
		return
	var rad := lens_px
	var y0 := int(floor(center.y - rad))
	var y1 := int(ceil(center.y + rad))
	for y in range(y0, y1):
		var dy := float(y) + 0.5 - center.y
		var remain := rad * rad - dy * dy
		if remain <= 0.0:
			continue
		var half_w := sqrt(remain)
		var dest := Rect2(center.x - half_w, float(y), half_w * 2.0, 1.0)
		var src := Rect2(cursor.x - half_w / ZOOM, cursor.y + dy / ZOOM, half_w * 2.0 / ZOOM, 1.0 / ZOOM)
		_overlay.draw_texture_rect_region(_lens_tex, dest, src)
	if show_pins:
		for i in pins.size():
			var p: Array = pins[i]
			var pc := center + ((Vector2(int(p[0]), int(p[1])) + Vector2(0.5, 0.5)) - cursor) * ZOOM
			if pc.distance_to(center) < rad + PIN_R * 2.0:
				_draw_ring(pc, PIN_R * 2.0, false, i == selected)
		if pending.x >= 0:
			var qc := center + ((Vector2(pending) + Vector2(0.5, 0.5)) - cursor) * ZOOM
			_draw_ring(qc, PIN_R * 2.0, true)
	var cell := Rect2(center + (Vector2(hover) - cursor) * ZOOM, Vector2(ZOOM, ZOOM))
	if pending.x < 0 and selected < 0:
		_overlay.draw_rect(cell.grow(1.0), CardTheme.color(&"wood_0"), false, 1.0)
		_overlay.draw_rect(cell, CardTheme.color(&"gold_pale"), false, 1.0)
	_overlay.draw_arc(center, rad, 0.0, TAU, 48, CardTheme.color(&"wood_0"), 5.0, true)
	_overlay.draw_arc(center, rad, 0.0, TAU, 48, CardTheme.color(&"umber"), 2.0, true)
