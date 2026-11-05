# Shared layout for the bankruptcy ladder. No class_name (C11 only preloads it).
# Text goes through CardText, color through CardTheme, pictures through CardArt.
# TODO(design): query("estates") is specified as an array; Mock wraps {"estates": [EstateView]}.
# Reskin 10-22 (web prototype): overlays are a dark modal panel (CardTheme.modal_style) centred on screen and
# never wider than OVERLAY_MAX (b26); the estates drawer sits inside the right drawer frame (b19); text is light
# on dark (hud_ink, gold_hi for titles), buttons use the table theme (wood).
extends RefCounted

const Kit = preload("res://scripts/cards/ui/slots/drawer_kit.gd")

const VIEWPORT := Vector2(1280, 720)
const PANEL_POS := Vector2(100, 40)
const PANEL_SIZE := Vector2(1080, 640)
const DRAWER_SIZE := Vector2(388, 630)
const OVERLAY_W := 720.0
## Gap between the estates drawer's scroll area and the close-day plate below it.
const END_DAY_GAP := 8.0


## Overlay chrome: a dark modal panel OVERLAY_W wide, centred in the viewport, growing with its content but
## clamped to CardLayout.OVERLAY_MAX (call fit_overlay after filling). The host's overlay layer draws the shade.
static func mount(host: Control, _frame: StringName) -> Dictionary:
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.offset_left = 0
	host.offset_top = 0
	host.offset_right = 0
	host.offset_bottom = 0
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := Panel.new()
	shade.name = "shade"
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_theme_stylebox_override("panel", CardTheme.modal_shadow_style())
	host.add_child(shade)
	var box := PanelContainer.new()
	box.name = "box"
	box.custom_minimum_size = Vector2(OVERLAY_W, 0)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.clip_contents = true
	box.add_theme_stylebox_override("panel", CardTheme.modal_style())
	host.add_child(box)
	var body := VBoxContainer.new()
	body.name = "body"
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	fit_overlay.call_deferred(box)
	return {"shade": shade, "box": box, "body": body}


## Centre the overlay box on screen at its content size, never past CardLayout.OVERLAY_MAX (b26).
static func fit_overlay(box: Control) -> void:
	if box == null or not is_instance_valid(box):
		return
	var lim := CardLayout.OVERLAY_MAX
	var want := box.get_combined_minimum_size()
	var sz := Vector2(minf(maxf(want.x, OVERLAY_W), lim.size.x), minf(want.y, lim.size.y))
	box.size = sz
	box.position = (Vector2(1280, 720) - sz) * 0.5
	var host := box.get_parent() as Control
	var shade := host.get_node_or_null("shade") as Control if host != null else null
	if shade != null:
		shade.position = box.position
		shade.size = box.size


## Right drawer inner block (contract 1.3 §7.11.8: 388x630 inside the right frame, inset 16, title row 44).
## The host (C01 drawer_host) draws the frame, its title and 合上; this block is placed inside it (b19) and
## scrolls when the rows run long.
static func mount_drawer(host: Control, _frame: StringName) -> Dictionary:
	Kit.place(host, "r")
	var box := Kit.scroll()
	box.name = "box"
	box.position = Vector2(0, Kit.TOP_PAD)
	# The close-day plate (CardLayout.END_DAY) is drawn over the right drawer's lower right (contract
	# 7.11.11); the rows scroll above it instead of running underneath (QA 10-25: the last estate row was hidden).
	var foot := CardLayout.END_DAY.position.y - END_DAY_GAP - host.position.y
	box.size = Vector2(host.size.x, minf(host.size.y, foot) - Kit.TOP_PAD)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	host.add_child(box)
	var body := VBoxContainer.new()
	body.name = "body"
	body.add_theme_constant_override("separation", 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size = Vector2(host.size.x - 12.0, 0)
	box.add_child(body)
	return {"box": box, "body": body}


static func backdrop(host: Control, art_id: String) -> TextureRect:
	var r := TextureRect.new()
	r.name = "backdrop"
	r.texture = CardArt.texture(art_id)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(r)
	host.move_child(r, 0)
	return r


static func art_rect(art_id: String, scale: int, fallback: Vector2i) -> TextureRect:
	var r := TextureRect.new()
	r.texture = CardArt.texture(art_id)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b := CardArt.base_size(art_id)
	if b.x <= 0 or b.y <= 0:
		b = fallback
	r.custom_minimum_size = Vector2(b * scale)
	return r


## One line of light text on the dark panels: brush gold for titles (>= 20), hud_ink for body, text_2 for drafts.
static func line(text: String, size: int, draft: bool) -> Label:
	_colors()
	var l := Label.new()
	l.text = text
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	var title := size >= 20
	l.add_theme_font_override("font", CardTheme.font_title() if title else CardTheme.font_body())
	l.add_theme_color_override("font_color", _ink_soft if draft else (_gold if title else _ink))
	l.custom_minimum_size = Vector2(0, size + 10)
	return l


static func number_label(n: int) -> Label:
	var l := line(str(n), 18, false)
	l.custom_minimum_size = Vector2(72, 28)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


static var _ink: Color
static var _ink_soft: Color
static var _gold: Color
static var _seal: Color
static var _colors_ready := false


## A wood button from the table theme (prototype .btn); draft text is dimmer. Callers set variations / sizes.
static func button(text: String, draft: bool) -> Button:
	_colors()
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.clip_text = true
	b.custom_minimum_size = Vector2(120, 40)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_font_override("font", CardTheme.font_body())
	if draft:
		b.add_theme_color_override("font_color", _ink_soft)
	return b


static func _colors() -> void:
	if _colors_ready:
		return
	_colors_ready = true
	_ink = CardTheme.color(&"hud_ink")
	_ink_soft = CardTheme.color(&"text_2")
	_gold = CardTheme.color(&"gold_hi")
	_seal = CardTheme.color(&"seal")


static func clear(box: Node) -> void:
	if box == null:
		return
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


static func buttons(host: Node) -> Array:
	var out: Array = []
	_collect(host, out)
	return out


static func chain_focus(host: Control, grab: bool) -> void:
	var live := buttons(host)
	var n := live.size()
	if n == 0:
		return
	for i in n:
		var a: Control = live[i]
		var nxt: Control = live[(i + 1) % n]
		var prv: Control = live[posmod(i - 1, n)]
		a.focus_next = a.get_path_to(nxt)
		a.focus_previous = a.get_path_to(prv)
	if grab and host.is_inside_tree():
		(live[0] as Control).grab_focus()


## "close" = caller should close; "eat" = key consumed; "" = not ours.
static func handle_key(host: Control, event: InputEvent, allow_close: bool) -> String:
	if host == null or not host.is_visible_in_tree():
		return ""
	var code := keycode(event)
	if code == 0:
		return ""
	if code == KEY_ESCAPE:
		return "close" if allow_close else "eat"
	if code == KEY_TAB:
		move_focus(host, (event as InputEventKey).shift_pressed)
		return "eat"
	if code == KEY_ENTER or code == KEY_KP_ENTER:
		activate_focus(host)
		return "eat"
	return ""


static func keycode(event: InputEvent) -> int:
	if not (event is InputEventKey):
		return 0
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return 0
	return int(k.keycode)


static func move_focus(host: Control, back: bool) -> void:
	var live := buttons(host)
	if live.is_empty() or not host.is_inside_tree():
		return
	var cur := host.get_viewport().gui_get_focus_owner()
	var i := live.find(cur)
	if i < 0:
		i = live.size() - 1 if back else 0
	else:
		var step := -1 if back else 1
		i = posmod(i + step, live.size())
	(live[i] as Control).grab_focus()


static func activate_focus(host: Control) -> void:
	var live := buttons(host)
	if live.is_empty() or not host.is_inside_tree():
		return
	var cur := host.get_viewport().gui_get_focus_owner()
	var b: Button = (cur as Button) if cur is Button and live.has(cur) else (live[0] as Button)
	b.grab_focus()
	b.pressed.emit()


static func show_reason(label: Label, result: Dictionary) -> void:
	if label == null:
		return
	var key := str(result.get("reason_key", ""))
	if key == "":
		label.text = ""
		return
	label.text = CardText.t(key)
	var draft := CardText.is_draft(key)
	label.add_theme_color_override("font_color", CardTheme.color(&"text_2" if draft else &"bad"))


static func _collect(n: Node, out: Array) -> void:
	if n is Button:
		var b := n as Button
		if b.visible and b.focus_mode != Control.FOCUS_NONE:
			out.append(b)
	for c in n.get_children():
		_collect(c, out)
