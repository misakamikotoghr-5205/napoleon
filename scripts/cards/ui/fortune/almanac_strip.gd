# Almanac strip in the top bar: suitable row, avoid row, a small mark on actions the player already did.
# Words come from CardText.ui("g05.almanac.<action>") (keys belong to G05) and c07.strip.yi / c07.strip.ji.
# Owner C07. Frozen: refresh(view). Guide anchor: a.almanac.
class_name CardAlmanacStrip
extends Control

const SIZE := Vector2(196, 40)
const FONT_SIZE := 14
const PREFIX_W := 64.0
const ROW_H := 20.0
const MIN_SLOT := 28
## One-row strip in the HUD: the 宜 / 忌 prefix is one glyph wide.
const HUD_PREFIX_W := 18.0

var _tips: PackedStringArray = []
## Colour key for the row being placed in the HUD strip (empty = the paper colours of the 40px strip).
var _row_tone: StringName = &""


func _ready() -> void:
	if size == Vector2.ZERO or size == SIZE:
		custom_minimum_size = SIZE
		size = SIZE
	else:
		custom_minimum_size = size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "."
	CardAnchors.register(&"a.almanac", self)


func refresh(view: Dictionary) -> void:
	if size == Vector2.ZERO or size == SIZE:
		custom_minimum_size = SIZE
		size = SIZE
	else:
		custom_minimum_size = size
	clip_contents = true
	_tips = PackedStringArray()
	for c in get_children():
		remove_child(c)
		c.free()
	var alm := _almanac_of(view)
	var done := _as_array(alm.get("done", []))
	if size.y < SIZE.y and _as_array(alm.get("yi", [])).is_empty() and _as_array(alm.get("ji", [])).is_empty():
		# HUD 一行：月初转轮盘前还没有黄历，光秃秃的“宜 / 忌”两个字不画。
		return
	if size.y < SIZE.y:
		# HUD 一行（换皮，原型 .alm）：宜 almanac_yi 绿、忌 almanac_ji 红；字前面的“宜/忌”紧贴着字。
		var half_w := floorf((size.x - 4.0) * 0.5)
		_row_tone = &"almanac_yi"
		_place_row(0.0, "c07.strip.yi", _as_array(alm.get("yi", [])), done, 0.0, half_w, size.y, HUD_PREFIX_W)
		_row_tone = &"almanac_ji"
		_place_row(0.0, "c07.strip.ji", _as_array(alm.get("ji", [])), done, half_w + 4.0, size.x - half_w - 4.0, size.y, HUD_PREFIX_W)
		_row_tone = &""
	else:
		_place_row(0.0, "c07.strip.yi", _as_array(alm.get("yi", [])), done)
		_place_row(ROW_H, "c07.strip.ji", _as_array(alm.get("ji", [])), done)


func _make_custom_tooltip(_for_text: String) -> Object:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for text in _tips:
		if text == "":
			continue
		var l := Label.new()
		l.text = text
		l.tooltip_text = text
		l.add_theme_font_override("font", CardTheme.font_body())
		l.add_theme_font_size_override("font_size", FONT_SIZE)
		l.add_theme_color_override("font_color", CardTheme.color(&"ink"))
		box.add_child(l)
	return box


func _almanac_of(view: Dictionary) -> Dictionary:
	var notice = view.get("notice", {})
	if typeof(notice) != TYPE_DICTIONARY:
		return {}
	var raw = notice.get("almanac", {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


func _as_array(v) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []


func _place_row(
	y: float,
	prefix_key: String,
	actions: Array,
	done: Array,
	x0: float = 0.0,
	row_w: float = SIZE.x,
	row_h: float = ROW_H,
	prefix_w: float = PREFIX_W
) -> void:
	var prefix := CardText.ui(prefix_key)
	_tips.append(prefix)
	var lab := _label(prefix, CardText.is_draft(prefix_key))
	add_child(lab)
	lab.position = Vector2(x0, y)
	lab.size = Vector2(prefix_w, row_h)
	var rows: Array = []
	for a in actions:
		if typeof(a) != TYPE_STRING and typeof(a) != TYPE_STRING_NAME:
			continue
		var act := str(a)
		var word := CardText.ui("g05.almanac." + act)
		_tips.append(word)
		rows.append({"act": act, "word": word, "mark": _listed(act, done)})
	var gap := 2.0 if row_h > ROW_H else 4.0
	var x := x0 + prefix_w + gap
	var avail := x0 + row_w - x
	var n: int = rows.size()
	var slot := int(avail / float(maxi(n, 1)))
	var shown := n
	var ellipsis := false
	if n > 0 and slot < MIN_SLOT:
		ellipsis = true
		shown = int((avail - 16.0) / float(MIN_SLOT))
		shown = clampi(shown, 0, n)
		slot = MIN_SLOT
	_place_actions(rows, shown, slot, x, y, row_h)
	if ellipsis:
		var ell := _label("...", false)
		ell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ell.tooltip_text = ""
		add_child(ell)
		var ex := x + float(shown * slot)
		ell.position = Vector2(minf(ex, x0 + row_w - 16.0), y)
		ell.size = Vector2(16, row_h)


func _place_actions(rows: Array, shown: int, slot: int, x: float, y: float, row_h: float = ROW_H) -> void:
	for i in range(mini(shown, rows.size())):
		var row: Dictionary = rows[i]
		var marked := bool(row["mark"])
		var box := Control.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.set_meta("action", str(row["act"]))
		add_child(box)
		box.position = Vector2(x, y)
		box.size = Vector2(slot, row_h)
		var text_w := float(slot) - (14.0 if marked else 0.0)
		var word := str(row["word"])
		var al := _label(word, CardText.is_draft("g05.almanac." + str(row["act"])))
		al.tooltip_text = word
		box.add_child(al)
		al.position = Vector2.ZERO
		al.size = Vector2(maxf(8.0, text_w), row_h)
		if marked:
			var mark := DoneMark.new()
			mark.name = "DoneMark"
			mark.position = Vector2(maxf(0.0, text_w), floorf((row_h - 14.0) * 0.5))
			mark.size = Vector2(12, 14)
			box.add_child(mark)
		x += float(slot)


func _label(text: String, draft: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.tooltip_text = text
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", CardTheme.font_body())
	l.add_theme_font_size_override("font_size", FONT_SIZE)
	# The body font's box is taller than half of the 40px strip. Tighten the line so two rows fit.
	l.add_theme_constant_override("line_spacing", -8)
	var color_key: StringName = &"hud_ink" if size.y < SIZE.y else (&"ink_soft" if draft else &"ink")
	if size.y < SIZE.y and _row_tone != &"":
		color_key = _row_tone
	l.add_theme_color_override("font_color", CardTheme.color(color_key))
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	return l


func _listed(act: String, done: Array) -> bool:
	for d in done:
		if str(d) == act:
			return true
	return false


class DoneMark:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var ink := CardTheme.color(&"jade")
		draw_line(Vector2(1, 8), Vector2(4, 12), ink, 2.0)
		draw_line(Vector2(4, 12), Vector2(11, 2), ink, 2.0)
