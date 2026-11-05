# Shared builders for the month panels. No class_name (not a frozen type).
# Text goes through CardText. Colors go through CardTheme.
# Reskin 10-22 (SPEC 3.4, 10.5): dark .modal sheets (deep wood inside the pixel frame.dialog frame,
# brush-gold titles, light text) and the paper .ledgerbook for the month accounts.
# Owner C09.
extends RefCounted

const VIEW := Vector2(1280, 720)
const TITLE_SIZE := 30


static func take_focus(panel: Control) -> void:
	if panel.is_inside_tree():
		panel.grab_focus()
	elif not panel.ready.is_connected(panel.grab_focus):
		panel.ready.connect(panel.grab_focus, CONNECT_ONE_SHOT)


static func prepare(panel: Control) -> void:
	# Top-left anchors so an explicit 1280x720 size is not overwritten or warned about.
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.focus_mode = Control.FOCUS_ALL
	panel.position = Vector2.ZERO
	panel.size = VIEW


static func clear(panel: Control) -> void:
	var kids := panel.get_children()
	for c in kids:
		panel.remove_child(c)
		c.free()


## Backdrop. Under the modal host (meta "shade") the host already dims the table once; a second shade
## would double it, so ours stays clear there.
static func shade(parent: Control) -> ColorRect:
	var s := ColorRect.new()
	s.name = "Shade"
	s.color = Color.TRANSPARENT if parent.has_meta("shade") else CardTheme.color(&"shade")
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.position = Vector2.ZERO
	s.size = VIEW
	parent.add_child(s)
	return s


## Dark sheet (prototype .modal) at rect, with the soft drop shadow under it.
static func modal(parent: Control, rect: Rect2) -> PanelContainer:
	return _box(parent, rect, CardTheme.modal_style())


## Ledger paper (prototype .ledgerbook) at rect.
static func book(parent: Control, rect: Rect2) -> PanelContainer:
	return _box(parent, rect, CardTheme.paper_book_style())


## Old name kept for callers: the overlay-sized dark sheet.
static func paper(parent: Control) -> PanelContainer:
	return modal(parent, CardLayout.OVERLAY_MAX)


static func centred(sz: Vector2) -> Rect2:
	return Rect2(((VIEW - sz) / 2.0).round(), sz)


static func _box(parent: Control, rect: Rect2, style: StyleBox) -> PanelContainer:
	var lift := Panel.new()
	lift.name = "BoxShadow"
	lift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lift.add_theme_stylebox_override("panel", CardTheme.modal_shadow_style())
	place(lift, rect.position, rect.size)
	parent.add_child(lift)
	var box := PanelContainer.new()
	box.name = "Box"
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.position = rect.position
	box.size = rect.size
	box.custom_minimum_size = rect.size
	box.add_theme_stylebox_override("panel", style)
	parent.add_child(box)
	return box


## Text. title = brush font. on_paper = ink on the ledger paper; otherwise light ink on the dark sheet
## (titles gold). Draft text is dimmer either way.
static func label(text: String, size: int, title: bool, draft: bool, on_paper: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_constant_override("line_spacing", 6)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_override("font", CardTheme.font_title() if title else CardTheme.font_body())
	l.add_theme_font_size_override("font_size", maxi(size, 14))
	l.add_theme_color_override("font_color", CardTheme.color(ink(title, draft, on_paper)))
	return l


static func ink(title: bool, draft: bool, on_paper: bool) -> StringName:
	if on_paper:
		if draft:
			return &"ink_soft"
		return &"seal_dark" if title else &"ink"
	if draft:
		return &"text_3"
	return &"gold_hi" if title else &"hud_ink"


## Secondary line (prototype .modal p: 14px, --text-2 on the dark sheet, --ink-3 on paper).
static func note(text: String, draft: bool, on_paper: bool = false) -> Label:
	var l := label(text, 14, false, draft, on_paper)
	var key := &"ink_3" if on_paper else &"text_2"
	if draft:
		key = &"ink_soft" if on_paper else &"text_3"
	l.add_theme_color_override("font_color", CardTheme.color(key))
	return l


## Small pill (goal marks: main / done / not done).
static func chip(text: String, bg: StringName, fg: StringName) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.add_theme_stylebox_override("panel", CardTheme.pill_style(bg, &"", 4, 8.0, 1.0))
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", CardTheme.font_body_bold())
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", CardTheme.color(fg))
	pill.add_child(l)
	return pill


## Themed wood button (the root card theme draws it); primary = the gold .btn.primary.
static func button(text: String, node_name: String, primary: bool = false) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.theme_type_variation = &"PrimaryButton" if primary else &""
	b.custom_minimum_size = Vector2(160, 44)
	b.size = b.custom_minimum_size
	b.add_theme_font_size_override("font_size", 17)
	return b


static func place(node: Control, at: Vector2, sz: Vector2) -> void:
	node.position = at
	node.size = sz
	node.custom_minimum_size = sz
