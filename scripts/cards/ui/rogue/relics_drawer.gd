# Rogue v1 curio shelf drawer (relics, right drawer; the scene's curio hotspot opens it). Read-only: the count of
# relics on the shelf and its cells (visible counts), one paper row per relic (picture x2, name, depth word, its whole
# history, what it does for the shop, its flaw when it has one), then the customer sources at the door this month.
# While the shop is lost or the player is jailed the relics rest: one line says so and every row is dimmed. When an
# offer is still open, a button on top hands over to the stocktake overlay (close_requested {"next": {kind:
# stocktake, ...}}).
# No effect sizes anywhere. Views without relics / stock (example set, Mock day_full) show the empty state.
# Owner RG4. Contract: docs/cards/rogue/ROGUE_V1.md sections 4.8, 7.1, 7.3, 11.
extends CardPanel

const Ui = preload("res://scripts/cards/ui/rogue/rogue_ui.gd")
const DrawerHost = preload("res://scripts/cards/ui/table/drawer_host.gd")

const KIND := &"relics"
## Inside of the right drawer frame: 16 px padding under the host's title row, like the other right drawers.
const PAD := 16.0
const TITLE_ROW := DrawerHost.HEAD_H + 1.0
const INNER := Vector2(388, 630)
const FOOT_GAP := 8.0
const ROW_H := 96.0
const ART_RELIC := Vector2(64, 64)
const ART_SOURCE := Vector2(64, 48)
const DEFAULT_CAP := 6

var _root: Panel
var _list: VBoxContainer
var _rows: VBoxContainer
var _pending: Button
var _closed: bool = false
var _looked: bool = false


func _ready() -> void:
	# The host pins this panel over the whole screen; only the content box takes the mouse, so the drawer
	# frame's close button and the scrim stay clickable.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _exit_tree() -> void:
	engine = null
	bus = null


func open(_args: Dictionary) -> void:
	_closed = false
	_looked = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure()
	_refill(engine.view() if engine != null else {})


func refresh(view: Dictionary) -> void:
	if _closed or _list == null:
		return
	_refill(view)


## Look once, then close. Never picks anything for the player.
func autoplay_step() -> bool:
	if _looked or _closed:
		return false
	_looked = true
	dismiss()
	return true


func dismiss() -> void:
	if _closed:
		return
	_closed = true
	close_requested.emit({})


func pending_button() -> Button:
	return _pending


func rows() -> VBoxContainer:
	return _rows


func _ensure() -> void:
	if _root != null:
		return
	var rect := CardLayout.DRAWER_R
	_root = Panel.new()
	_root.name = "RelicsBox"
	_root.position = rect.position + Vector2(PAD, TITLE_ROW)
	_root.size = INNER
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_root)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.position = Vector2(0, 8)
	var foot := CardLayout.END_DAY.position.y - FOOT_GAP - _root.position.y
	scroll.size = Vector2(INNER.x, minf(INNER.y, foot) - 8.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_root.add_child(scroll)
	_list = Ui.column(8)
	_list.name = "List"
	_list.custom_minimum_size = Vector2(INNER.x - 12.0, 0)
	scroll.add_child(_list)


func _refill(view: Dictionary) -> void:
	_ensure()
	Ui.clear(_list)
	_pending = null
	_rows = null
	var relics := Ui.dict(view.get("relics", {}))
	var stock := Ui.dict(view.get("stock", {}))
	var open_offer := str(stock.get("open", ""))
	if open_offer != "":
		_pending_button(open_offer)
	var dormant := bool(relics.get("dormant", false))
	var held := _held(relics)
	if not relics.is_empty():
		var n := int(relics.get("count", held.size()))
		var cap := int(relics.get("cap", DEFAULT_CAP))
		_list.add_child(_note("Count", "rg4.relics.count", {"n": n, "cap": cap}, &"hud_ink", 16))
	if dormant:
		_list.add_child(_note("Dormant", "rg4.relics.dormant", {}, &"almanac_ji", 14))
	_rows = Ui.column(8)
	_rows.name = "Rows"
	_list.add_child(_rows)
	CardAnchors.register(&"a.relics.list", _rows, _visible_part.bind(_rows))
	if held.is_empty():
		_rows.add_child(_note("Empty", "rg4.relics.empty", {}, &"text_2", 14))
	for i in held.size():
		var row := _relic_row(held[i], i)
		if dormant:
			row.modulate = CardTheme.color(&"ink_soft")
		_rows.add_child(row)
	_sources_section(Ui.array(stock.get("sources", [])))


## The rows clipped to the scroll window: a full shelf with long words scrolls, and the anchor is the part on screen.
func _visible_part(node: Control) -> Rect2:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return Rect2()
	var rect := node.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, node.size)
	var scroll := _list.get_parent() as Control if _list != null else null
	if scroll == null:
		return rect
	return rect.intersection(scroll.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, scroll.size))


func _held(relics: Dictionary) -> Array:
	var out: Array = []
	for row in Ui.array(relics.get("held", [])):
		if typeof(row) == TYPE_DICTIONARY and str(row.get("id", "")) != "":
			out.append(row)
	return out


func _pending_button(offer: String) -> void:
	_pending = Button.new()
	_pending.name = "Pending"
	_pending.text = CardText.ui("rg4.relics.pending")
	_pending.theme_type_variation = &"PrimaryButton"
	_pending.focus_mode = Control.FOCUS_ALL
	_pending.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_pending.custom_minimum_size = Vector2(0, 38)
	_pending.pressed.connect(_hand_over.bind(offer))
	_list.add_child(_pending)


## The stocktake overlay takes over; the root opens it from result.next (card_game_root._on_follow_up).
func _hand_over(offer: String) -> void:
	if _closed:
		return
	_closed = true
	close_requested.emit({"next": {"kind": "stocktake", "args": {"offer": offer}}})


func _relic_row(row: Dictionary, i: int) -> PanelContainer:
	var id := str(row.get("id", ""))
	var look := Ui.look_of("relic", str(row.get("depth", "")))
	var box := _row_box("Relic%d" % i, id, look)
	var line: HBoxContainer = box.get_child(0)
	line.add_child(_picture(str(row.get("art", "")), ART_RELIC))
	var col := _words_column(id)
	line.add_child(col)
	var head: HBoxContainer = col.get_child(0)
	var word_key := Ui.depth_word_key(look)
	var tag := Ui.pill(CardText.ui(word_key), Ui.frame_key(look), Ui.PILL_INKS.get(look, &"paper"), 14,
		CardText.is_draft(word_key))
	tag.name = "Depth"
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tag)
	if CardText.has_text(id + "#body"):
		var story := Ui.flow(Ui.card_text(id, "body"), 13, &"card_sub_ink", Ui.is_draft(id, "body"))
		story.name = "Story"
		col.add_child(story)
		col.move_child(story, 1)
	if CardText.has_text(id + "#lines.flaw"):
		col.add_child(_marked("Flaw", "rg4.stock.flaw", &"seal_dark", Ui.card_text(id, "lines.flaw"), &"seal_dark", false))
	return box


## A paper row (at least ROW_H high, as tall as its words need) with the depth colour as a bar on the left.
func _row_box(node_name: String, id: String, look: String) -> PanelContainer:
	var box := PanelContainer.new()
	box.name = node_name
	box.set_meta("item", id)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.custom_minimum_size = Vector2(0, ROW_H)
	box.add_theme_stylebox_override("panel", Ui.row_style(look))
	var line := Ui.row_box(10)
	line.name = "Line"
	box.add_child(line)
	return box


## Name (with room for a tag after it) and what it does for the shop, every word of it.
func _words_column(id: String) -> VBoxContainer:
	var col := Ui.column(3)
	col.name = "Words"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := Ui.row_box(8)
	head.name = "Head"
	col.add_child(head)
	var title := Ui.label(Ui.card_text(id, "title"), 18, &"ink", &"title", Ui.is_draft(id, "title"))
	title.name = "Name"
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	col.add_child(_marked("Use", "rg4.stock.use", &"ledger_in", Ui.card_text(id, "use"), &"ink", Ui.is_draft(id, "use")))
	return col


## A small mark ("use" / "flaw", as on the stocktake cards) and the words after it, wrapped, never cut.
func _marked(node_name: String, mark_key: String, mark_bg: StringName, text: String, tone: StringName,
		draft: bool) -> HBoxContainer:
	var row := Ui.row_box(6)
	row.name = node_name + "Row"
	var mark := Ui.pill(CardText.ui(mark_key), mark_bg, &"paper", 14, CardText.is_draft(mark_key))
	mark.name = node_name + "Mark"
	row.add_child(mark)
	var words := Ui.flow(text, 14, tone, draft)
	words.name = node_name
	row.add_child(words)
	return row


func _sources_section(sources: Array) -> void:
	_list.add_child(_divider())
	var head := Ui.label(CardText.ui("rg4.relics.sources"), 15, &"gold_hi", &"bold", CardText.is_draft("rg4.relics.sources"))
	head.name = "SourcesHead"
	_list.add_child(head)
	var shown := 0
	for row in sources:
		if typeof(row) != TYPE_DICTIONARY or str(row.get("id", "")) == "":
			continue
		_list.add_child(_source_row(row, shown))
		shown += 1
	if shown == 0:
		_list.add_child(_note("SourcesEmpty", "rg4.relics.sources_empty", {}, &"text_2", 14))


func _source_row(row: Dictionary, i: int) -> PanelContainer:
	var id := str(row.get("id", ""))
	var box := _row_box("Source%d" % i, id, "source")
	box.custom_minimum_size = Vector2.ZERO
	var line: HBoxContainer = box.get_child(0)
	line.add_child(_picture(str(row.get("art", "")), ART_SOURCE))
	var col := _words_column(id)
	line.add_child(col)
	var until := Ui.label(CardText.ui("rg4.stock.source_until"), 14, &"ink_soft", &"bold",
		CardText.is_draft("rg4.stock.source_until"))
	until.name = "Until"
	col.add_child(until)
	return box


## Pixel art in a dark well, nearest filter, integer scale.
func _picture(art_id: String, box: Vector2) -> PanelContainer:
	var well := PanelContainer.new()
	well.name = "Well"
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	well.add_theme_stylebox_override("panel", Ui.well_style())
	var pic := Ui.art(art_id, box)
	pic.name = "Picture"
	well.add_child(pic)
	return well


func _note(node_name: String, key: String, args: Dictionary, tone: StringName, size: int) -> Label:
	var l := Ui.label(CardText.ui(key, args), size, tone, &"body", CardText.is_draft(key))
	l.name = node_name
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(INNER.x - 16.0, 0)
	return l


func _divider() -> ColorRect:
	var c := ColorRect.new()
	c.name = "Divider"
	c.color = CardTheme.color(&"line")
	c.custom_minimum_size = Vector2(0, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
