# C08 shared chrome: one dark modal sheet (the web prototype's .modal: deep wood fill inside the pixel
# frame.dialog frame), brush-gold title, light body text, themed wood buttons. No class_name.
# Owner C08. Contract: docs/cards/CARDS_INTERFACES.md section 3.3 C08, 7.8, 11.2. Reskin 10-22 (SPEC 3.4, 10.5).
extends RefCounted

const BOX := Vector2(980, 560)
const VIEW := Vector2(1280, 720)
const TITLE_SIZE := 30
const PAD := Vector2(CardTheme.MODAL_PAD_H + 14.0, CardTheme.MODAL_PAD_V + 14.0)


static func prepare(panel: Control) -> void:
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	while panel.get_child_count() > 0:
		var c: Node = panel.get_child(0)
		panel.remove_child(c)
		c.free()


## Where the panel's own (0, 0) sits on screen. The modal host pins overlays at CardLayout.OVERLAY_MAX,
## so a sheet centred in panel space would sit off-centre on screen (same bug as b09).
static func origin(panel: Control) -> Vector2:
	if panel.is_inside_tree():
		return panel.get_global_transform_with_canvas().origin
	return panel.position


## Full-screen click catcher behind the sheet. The host already draws the shade (meta "shade"), so the
## catcher stays clear there instead of stacking a second, darker rectangle over the table.
static func backdrop(panel: Control) -> ColorRect:
	var shade := ColorRect.new()
	shade.name = "Backdrop"
	shade.color = Color.TRANSPARENT if panel.has_meta("shade") else CardTheme.color(&"shade")
	shade.position = -origin(panel)
	shade.size = VIEW
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(shade)
	return shade


## The dark sheet, centred on the screen. Returns the content column inside the frame.
static func sheet(panel: Control, box_size: Vector2 = BOX) -> VBoxContainer:
	backdrop(panel)
	var lift := Panel.new()
	lift.name = "SheetShadow"
	lift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lift.add_theme_stylebox_override("panel", CardTheme.modal_shadow_style())
	panel.add_child(lift)
	var box := Panel.new()
	box.name = "Sheet"
	box.position = ((VIEW - box_size) / 2.0).round() - origin(panel)
	box.size = box_size
	box.custom_minimum_size = box_size
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_theme_stylebox_override("panel", CardTheme.modal_style())
	panel.add_child(box)
	lift.position = box.position
	lift.size = box_size
	var col := VBoxContainer.new()
	col.name = "Col"
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = PAD.x
	col.offset_top = PAD.y
	col.offset_right = -PAD.x
	col.offset_bottom = -PAD.y
	col.add_theme_constant_override("separation", 10)
	box.add_child(col)
	return col


## Light text for the dark sheet. size >= 22 is the brush title (gold); draft text is dimmer.
static func label(text: String, size: int, key: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := size >= 22
	l.add_theme_font_size_override("font_size", TITLE_SIZE if title else maxi(size, 14))
	l.add_theme_font_override("font", CardTheme.font_title() if title else CardTheme.font_body())
	var draft := CardText.is_draft(key)
	var ink := &"gold_hi" if title else &"hud_ink"
	if draft:
		ink = &"text_3"
	l.add_theme_color_override("font_color", CardTheme.color(ink))
	l.add_theme_constant_override("line_spacing", 4)
	return l


## Secondary line (prototype .modal p: 14px --text-2).
static func note(text: String, key: String) -> Label:
	var l := label(text, 14, key)
	l.add_theme_color_override("font_color", CardTheme.color(&"text_3" if CardText.is_draft(key) else &"text_2"))
	return l


## Themed wood button; primary = the prototype's gold .btn.primary. Draft text uses the theme's dim ink.
static func button(text: String, key: String, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(120, 40)
	b.theme_type_variation = &"PrimaryButton" if primary else &""
	if CardText.is_draft(key):
		b.add_theme_color_override("font_color", CardTheme.color(&"text_3"))
	return b


## Small gold diamond in front of a list line (drawn, so no text key is needed).
static func dot() -> Control:
	var d := Control.new()
	d.custom_minimum_size = Vector2(12, 24)
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gold := CardTheme.color(&"gold_deep")
	d.draw.connect(func() -> void:
		var c := Vector2(6, 12)
		d.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(4, 0), c + Vector2(0, 4),
			c + Vector2(-4, 0)]), gold))
	return d


## 后面还有可见的兄弟控件时，这一层不是最上面的面板，不该吃按键。
static func is_front(panel: Control) -> bool:
	var parent := panel.get_parent()
	if parent == null:
		return panel.is_visible_in_tree()
	var seen := false
	for node in parent.get_children():
		if node == panel:
			seen = true
			continue
		if seen and node is Control and (node as Control).is_visible_in_tree():
			return false
	return panel.is_visible_in_tree()


## 只认按下、不认连发；不是键就返回 -1。
static func pressed_key(event: InputEvent) -> int:
	if not (event is InputEventKey):
		return -1
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return -1
	return key.keycode
