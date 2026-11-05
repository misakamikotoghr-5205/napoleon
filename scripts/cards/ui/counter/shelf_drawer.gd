# Shelf drawer. Read-only it shows the stock; with pick_for set the player picks one piece for the counter.
# Owner C04. kind shelf, right drawer. Contract 7.11.8, C04 "10-13 change 2".
# Anchors: a.counter.stock while picking, a.shelf.list otherwise.
# Reskin 10-23 (prototype drawer, RESKIN SPEC 5.4): dark drawer body, a 3-column grid of cells
# (64 px item, bold name, grey category and condition) and dashed empty cells up to the shelf cap.
# Inside the host's drawer frame the frame draws the title and its own close; this panel only fills
# the body under the title bar. Opened bare (tests, no host) it draws the drawer itself, with a close
# labelled c04.drawer.close (b16: it used to read the counter's "come back later" and ran off screen).
class_name CardShelfDrawer
extends CardPanel

const KIND := &"shelf"
const COLS := 3
const GAP := 8.0
const CELL_H := 122.0
const DrawerHost = preload("res://scripts/cards/ui/table/drawer_host.gd")
const TITLE_BAR := DrawerHost.HEAD_H + 1.0   # the drawer frame title row and its rule (C01 drawer_host)
const INSET := 16.0

var _pick_for: String = ""
var _items: Array = []
var _wanted = null
var _acted: bool = false
var _root: Control
var _list: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _exit_tree() -> void:
	if _list != null and is_instance_valid(_list):
		CardAnchors.unregister(&"a.counter.stock", _list)
		CardAnchors.unregister(&"a.shelf.list", _list)
	engine = null
	bus = null


func open(args: Dictionary) -> void:
	_pick_for = str(args.get("pick_for", ""))
	_acted = false
	_items = _load_items()
	_rebuild()


func refresh(_view: Dictionary) -> void:
	_items = _load_items()
	_rebuild()


func autoplay_step() -> bool:
	if _acted:
		return false
	_acted = true
	if _pick_for != "":
		var item_id := _first_wanted()
		if item_id != "":
			_pick(item_id)
		else:
			close_requested.emit({})
		return true
	return true


# A buyer only takes what CounterView.stock lists (his category). The first shelf piece may not
# suit him; a wrong pick comes back wrong_category and autoplay would loop on the drawer.
# Only when the counter view has no stock list (old fixtures) fall back to the first piece.
func _first_wanted() -> String:
	var wanted = _wanted_ids()
	for entry in _items:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item_id := str(entry.get("item", ""))
		if item_id != "" and (wanted == null or (wanted as Dictionary).has(item_id)):
			return item_id
	return ""


## {item id: true} the buyer would take, or null when the counter view does not say.
func _wanted_ids():
	if engine == null or _pick_for == "":
		return null
	var q = engine.query(&"counter", {"uid": _pick_for})
	if typeof(q) != TYPE_DICTIONARY or typeof(q.get("stock")) != TYPE_ARRAY:
		return null
	var wanted := {}
	for entry in q["stock"]:
		wanted[str(entry.get("item", "")) if typeof(entry) == TYPE_DICTIONARY else str(entry)] = true
	return wanted


func dismiss() -> void:
	close_requested.emit({})


func _load_items() -> Array:
	if engine == null:
		return []
	var q = engine.query(&"stock", {})
	var items = q.get("items", []) if typeof(q) == TYPE_DICTIONARY else []
	return items if typeof(items) == TYPE_ARRAY else []


## True inside the host's drawer frame (it draws the title and the close).
func _framed() -> bool:
	var n: Node = get_parent()
	while n != null:
		if n is CardModalHost:
			return true
		n = n.get_parent()
	return false


func _rebuild() -> void:
	if _root != null:
		var old := _root
		_root = null
		if _list != null and is_instance_valid(_list):
			CardAnchors.unregister(&"a.counter.stock", _list)
			CardAnchors.unregister(&"a.shelf.list", _list)
		remove_child(old)
		old.queue_free()
	_wanted = _wanted_ids()
	var framed := _framed()
	var drawer := CardLayout.DRAWER_R
	# Global placement: the host pins drawer panels full screen today; keep working if it pins them
	# to the drawer body instead. _root spans the drawer and owns everything we draw.
	_root = Control.new()
	_root.name = "Drawer"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.position = drawer.position - _origin()
	_root.size = drawer.size
	add_child(_root)
	if not framed:
		_add_bare_chrome(drawer)
	var body := Control.new()
	body.name = "Body"
	body.mouse_filter = Control.MOUSE_FILTER_STOP
	body.position = Vector2(0, TITLE_BAR)
	body.size = Vector2(drawer.size.x, drawer.size.y - TITLE_BAR)
	_root.add_child(body)
	var w := drawer.size.x - INSET * 2.0
	var view := engine.view() if engine != null else {}
	var n := int(view.get("shelf_count", _items.size()))
	var caps: Dictionary = view.get("caps", {}) if typeof(view.get("caps")) == TYPE_DICTIONARY else {}
	var cap := int(caps.get("shelf", n))
	var count_ref := "c04.shelf.count"
	var count := _label(CardText.ui(count_ref, {"n": n, "cap": cap}), count_ref, 14, &"text_2")
	count.name = "Count"
	count.position = Vector2(INSET, 8)
	count.size = Vector2(w, 22)
	body.add_child(count)
	var y := 34.0
	if _pick_for != "":
		var hint := _label(CardText.ui("c04.shelf.pick_hint"), "c04.shelf.pick_hint", 14, &"gold_hi")
		hint.name = "PickHint"
		hint.position = Vector2(INSET, y)
		hint.size = Vector2(w, 22)
		body.add_child(hint)
		y += 26.0
	_list = Control.new()
	_list.name = "Grid"
	_list.position = Vector2(INSET, y + 4.0)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_list)
	var cell_w := floorf((w - GAP * float(COLS - 1)) / float(COLS))
	var i := 0
	for entry in _items:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		_list.add_child(_cell(entry, _slot_rect(i, cell_w)))
		i += 1
	# Empty cells fill the last row, at least two rows (prototype), never more than the cap: the
	# bright end-day button sits over the drawer's bottom right.
	var shown := mini(cap, maxi(COLS * 2, int(ceil(float(i) / float(COLS))) * COLS))
	while i < shown:
		_list.add_child(_empty_cell(_slot_rect(i, cell_w)))
		i += 1
	var rows := int(ceil(float(maxi(i, 1)) / float(COLS)))
	_list.size = Vector2(w, float(rows) * (CELL_H + GAP) - GAP)
	var anchor := &"a.counter.stock" if _pick_for != "" else &"a.shelf.list"
	var other := &"a.shelf.list" if anchor == &"a.counter.stock" else &"a.counter.stock"
	CardAnchors.unregister(other, _list)
	CardAnchors.register(anchor, _list)


func _origin() -> Vector2:
	return get_global_rect().position if is_inside_tree() else position


func _slot_rect(i: int, cell_w: float) -> Rect2:
	var col := i % COLS
	var row := floori(float(i) / float(COLS))
	return Rect2(float(col) * (cell_w + GAP), float(row) * (CELL_H + GAP), cell_w, CELL_H)


## Bare (no host frame): the drawer look, the brush title and a close of our own.
func _add_bare_chrome(drawer: Rect2) -> void:
	var bg := Panel.new()
	bg.name = "Frame"
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := CardTheme.flat_style(&"drawer_bg", &"umber", 3, 0)
	sb.bg_color = CardTheme.mix(&"tab_bg", &"drawer_bg")
	sb.border_width_right = 0
	bg.add_theme_stylebox_override("panel", sb)
	bg.position = Vector2.ZERO
	bg.size = drawer.size
	_root.add_child(bg)
	var title := _label(CardText.ui("c04.shelf.title"), "c04.shelf.title", 26, &"gold_hi")
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


func _cell(entry: Dictionary, rect: Rect2) -> Control:
	var iid := str(entry.get("item", ""))
	var pickable := _pick_for != "" and (_wanted == null or (_wanted as Dictionary).has(iid))
	var cell: Control
	if _pick_for != "":
		var hit := Button.new()
		hit.name = "Stock_%s" % iid
		hit.focus_mode = Control.FOCUS_ALL
		hit.add_theme_stylebox_override("normal", _cell_style(&"line", false))
		hit.add_theme_stylebox_override("disabled", _cell_style(&"line", false))
		hit.add_theme_stylebox_override("hover", _cell_style(&"gold_deep", true))
		hit.add_theme_stylebox_override("pressed", _cell_style(&"gold_hi", true))
		hit.add_theme_stylebox_override("hover_pressed", _cell_style(&"gold_hi", true))
		hit.add_theme_stylebox_override("focus", _cell_style(&"gold_deep", false))
		hit.disabled = not pickable
		if not pickable:
			hit.modulate = Color(1, 1, 1, 0.45)
		hit.pressed.connect(_pick.bind(iid))
		cell = hit
	else:
		var box := Panel.new()
		box.name = "Item_%s" % iid
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_stylebox_override("panel", _cell_style(&"line", false))
		cell = box
	cell.position = rect.position
	cell.size = rect.size
	var art := str(entry.get("art", ""))
	var tex := TextureRect.new()
	tex.texture = CardArt.texture(art)
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tex.position = Vector2(floorf((rect.size.x - 64.0) / 2.0), 8)
	tex.size = Vector2(64, 64)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(tex)
	var tpl := str(entry.get("template", ""))
	var item_name := CardText.item_text(tpl, "name") if tpl != "" else ""
	if item_name != "":
		var nm := _label(item_name, "item.%s#name" % tpl, 14, &"hud_ink")
		nm.add_theme_font_override("font", CardTheme.font_body_bold())
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.position = Vector2(4, 76)
		nm.size = Vector2(rect.size.x - 8.0, 20)
		cell.add_child(nm)
	var sub := _sub_line(entry)
	if sub != "":
		var lab := _label(sub, "c04.header.join", 14, &"text_3")
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lab.position = Vector2(4, 98)
		lab.size = Vector2(rect.size.x - 8.0, 20)
		cell.add_child(lab)
	return cell


## "category . condition" through the dialog's tag join key.
func _sub_line(entry: Dictionary) -> String:
	var parts: Array = []
	var cat := str(entry.get("cat", ""))
	if cat != "":
		parts.append(CardText.ui("c04.cat." + cat))
	if entry.has("condition_word"):
		parts.append(CardText.ui("c04.cond.%d" % clampi(int(entry["condition_word"]), 0, 4)))
	var out := ""
	for p in parts:
		if str(p) == "":
			continue
		out = str(p) if out == "" else CardText.ui("c04.header.join", {"a": out, "b": p})
	return out


func _empty_cell(rect: Rect2) -> Control:
	var box := Panel.new()
	box.name = "Empty"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := _cell_style(&"line", false)
	sb.bg_color.a *= 0.55
	sb.border_color.a *= 0.5
	box.add_theme_stylebox_override("panel", sb)
	box.position = rect.position
	box.size = rect.size
	var lab := _label(CardText.ui("c04.shelf.empty_cell"), "c04.shelf.empty_cell", 14, &"text_3")
	lab.modulate = Color(1, 1, 1, 0.6)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.position = Vector2.ZERO
	lab.size = rect.size
	box.add_child(lab)
	return box


func _cell_style(edge: StringName, lit: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CardTheme.color(&"wood_2") if lit else CardTheme.mix(&"wood_1", &"drawer_bg")
	sb.border_color = CardTheme.color(edge)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	return sb


func _pick(item_id: String) -> void:
	if item_id == "" or _pick_for == "" or engine == null:
		return
	engine.send(&"counter.pick_stock", {"uid": _pick_for, "item": item_id})
	close_requested.emit({})


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
