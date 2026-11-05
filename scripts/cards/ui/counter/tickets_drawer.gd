# Tickets drawer. Read-only: ticket number, who pawned it, the item, principal, days left. Foreign
# tickets carry a tag. Owner C04. kind tickets, right drawer. Anchor a.tickets.list.
# Reskin 10-23 (prototype drawer, RESKIN SPEC 5.4): dark drawer body, a grey note on top, one paper
# card per ticket (64 px item, bold "number + item", grey "who . principal . days"). Inside the host's
# drawer frame the frame draws the title and its close; bare (tests, no host) it draws the drawer
# itself with a close labelled c04.drawer.close (b16).
class_name CardTicketsDrawer
extends CardPanel

const KIND := &"tickets"
const DrawerHost = preload("res://scripts/cards/ui/table/drawer_host.gd")
const TITLE_BAR := DrawerHost.HEAD_H + 1.0   # the drawer frame title row and its rule (C01 drawer_host)
const INSET := 16.0
const END_DAY_GAP := 8.0   # gap above the close-day plate at the list's bottom

var _rows: Array = []
var _acted: bool = false
var _root: Control
var _list: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _exit_tree() -> void:
	if _list != null and is_instance_valid(_list):
		CardAnchors.unregister(&"a.tickets.list", _list)
	engine = null
	bus = null


func open(_args: Dictionary) -> void:
	_acted = false
	_rows = _load_rows()
	_rebuild()


func refresh(_view: Dictionary) -> void:
	_rows = _load_rows()
	_rebuild()


func autoplay_step() -> bool:
	if _acted:
		return false
	_acted = true
	return true


func dismiss() -> void:
	close_requested.emit({})


func _load_rows() -> Array:
	if engine == null:
		return []
	var view := engine.view()
	var rows = view.get("tickets", [])
	if typeof(rows) != TYPE_ARRAY or (rows as Array).is_empty():
		var q = engine.query(&"tickets", {})
		rows = q.get("tickets", []) if typeof(q) == TYPE_DICTIONARY else []
	return rows if typeof(rows) == TYPE_ARRAY else []


func _framed() -> bool:
	var n: Node = get_parent()
	while n != null:
		if n is CardModalHost:
			return true
		n = n.get_parent()
	return false


func _origin() -> Vector2:
	return get_global_rect().position if is_inside_tree() else position


func _rebuild() -> void:
	if _root != null:
		var old := _root
		_root = null
		if _list != null and is_instance_valid(_list):
			CardAnchors.unregister(&"a.tickets.list", _list)
		remove_child(old)
		old.queue_free()
	var drawer := CardLayout.DRAWER_R
	_root = Control.new()
	_root.name = "Drawer"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.position = drawer.position - _origin()
	_root.size = drawer.size
	add_child(_root)
	if not _framed():
		_add_bare_chrome(drawer)
	var body := Control.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_STOP
	body.position = Vector2(0, TITLE_BAR)
	body.size = Vector2(drawer.size.x, drawer.size.y - TITLE_BAR)
	_root.add_child(body)
	var w := drawer.size.x - INSET * 2.0
	var note := _label(CardText.ui("c04.tickets.note"), "c04.tickets.note", 14, &"text_2")
	note.name = "Note"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.clip_text = false
	note.position = Vector2(INSET, 8)
	note.size = Vector2(w, 0)
	body.add_child(note)
	var y := 8.0 + note.get_minimum_size().y + 10.0
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.position = Vector2(INSET, y)
	# QA 10-25: the close-day plate (CardLayout.END_DAY) sits over the drawer's lower right; with many
	# tickets the list scrolls above it instead of running underneath.
	var foot := CardLayout.END_DAY.position.y - END_DAY_GAP - (drawer.position.y + TITLE_BAR)
	scroll.size = Vector2(w, minf(body.size.y - 16.0, foot) - y)
	body.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "List"
	list.custom_minimum_size = Vector2(w - 8.0, 0)
	list.add_theme_constant_override("separation", 8)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(list)
	_list = list
	var stock := _stock_index()
	for entry in _rows:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		list.add_child(_row(entry, stock, w - 8.0))
	if list.get_child_count() == 0:
		var empty := _label(CardText.ui("c04.tickets.empty"), "c04.tickets.empty", 14, &"text_3")
		empty.name = "Empty"
		list.add_child(empty)
	CardAnchors.register(&"a.tickets.list", _list)


func _add_bare_chrome(drawer: Rect2) -> void:
	var bg := Panel.new()
	bg.name = "Frame"
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := CardTheme.flat_style(&"drawer_bg", &"umber", 3, 0)
	sb.bg_color = CardTheme.mix(&"tab_bg", &"drawer_bg")
	sb.border_width_right = 0
	bg.add_theme_stylebox_override("panel", sb)
	bg.size = drawer.size
	_root.add_child(bg)
	var title := _label(CardText.ui("c04.tickets.title"), "c04.tickets.title", 26, &"gold_hi")
	title.name = "Title"
	title.add_theme_font_override("font", CardTheme.font_title())
	title.position = Vector2(INSET, 8)
	title.size = Vector2(240, 40)
	_root.add_child(title)
	var close := Button.new()
	close.name = "CloseButton"
	close.theme_type_variation = &"SmallButton"
	close.text = CardText.ui("c04.drawer.close")
	close.set_meta("text_ref", "c04.drawer.close")
	close.clip_text = true
	close.pressed.connect(dismiss)
	_root.add_child(close)
	close.size = Vector2(72, 30)
	close.position = Vector2(drawer.size.x - INSET - 72.0, 12)


## One paper ticket: item picture, "number + item" in bold ink, "who . principal . days" below.
func _row(ticket: Dictionary, stock: Dictionary, w: float) -> Control:
	var no := int(ticket.get("no", 0))
	var card := PanelContainer.new()
	card.name = "Ticket_%d" % no
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", CardTheme.paper_card_style())
	card.custom_minimum_size = Vector2(w, 0)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(line)
	var iid := str(ticket.get("item", ""))
	var it: Dictionary = stock.get(iid, {})
	# A pawned piece is off the shelf, so the stock query rarely knows it: then the ticket prop x2.
	var art := str(it.get("art", ""))
	var zoom := 1
	if art == "" or CardArt.texture(art) == null:
		art = "prop.ticket"
		zoom = 2
	var tex_src := CardArt.texture(art)
	if tex_src != null:
		var well := CenterContainer.new()
		well.custom_minimum_size = Vector2(64, 64)
		well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(well)
		var tex := TextureRect.new()
		tex.name = "Art"
		tex.texture = tex_src
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_SCALE
		var base := CardArt.base_size(art)
		tex.custom_minimum_size = Vector2(base * zoom) if base != Vector2i.ZERO else Vector2(64, 64)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(tex)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(col)
	var tpl := str(it.get("template", ""))
	var item_name := CardText.item_text(tpl, "name") if tpl != "" else ""
	var head_ref := "c04.tickets.head" if item_name != "" else "c04.header.ticket"
	var head := _label(CardText.ui(head_ref, {"n": no, "name": item_name}), head_ref, 15, &"ink")
	head.name = "Head"
	head.add_theme_font_override("font", CardTheme.font_body_bold())
	head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(head)
	var parts: Array = []
	var person := str(ticket.get("person", ""))
	if person != "":
		parts.append(CardText.person_name(person))
	parts.append(CardText.ui("c04.header.principal", {"n": int(ticket.get("principal", 0))}))
	parts.append(CardText.ui("c04.header.days", {"n": int(ticket.get("days_left", 0))}))
	var sub := _label(_join(parts), "c04.header.join", 14, &"ink_soft")
	sub.name = "Sub"
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.clip_text = false
	col.add_child(sub)
	if bool(ticket.get("foreign", false)):
		var tag := _label(CardText.ui("c04.tickets.foreign"), "c04.tickets.foreign", 14, &"seal")
		tag.name = "Foreign"
		col.add_child(tag)
	return card


func _join(parts: Array) -> String:
	var out := ""
	for p in parts:
		if str(p) == "":
			continue
		out = str(p) if out == "" else CardText.ui("c04.header.join", {"a": out, "b": p})
	return out


func _stock_index() -> Dictionary:
	var out := {}
	if engine == null:
		return out
	var q = engine.query(&"stock", {})
	var items = q.get("items", []) if typeof(q) == TYPE_DICTIONARY else []
	if typeof(items) != TYPE_ARRAY:
		return out
	for it in items:
		if typeof(it) == TYPE_DICTIONARY:
			out[str(it.get("item", ""))] = it
	return out


func _label(text: String, ref: String, font_size: int, ink: StringName) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.clip_text = true
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.set_meta("text_ref", ref)
	lab.add_theme_font_override("font", CardTheme.font_body())
	lab.add_theme_font_size_override("font_size", font_size)
	var draft := ref != "" and CardText.is_draft(ref)
	lab.add_theme_color_override("font_color", CardTheme.color(&"text_3" if draft else ink))
	return lab
