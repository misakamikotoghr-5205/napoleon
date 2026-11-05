# Year jump: one report line per page, then a single year.next.
# Owner C09. Contract: docs/cards/CARDS_INTERFACES.md section 3.3 C09, 7.8, 7.11.
# Overlay on the night counter (C01 draws the scene). Esc / dismiss() closes and does not send year.next.
# Anchors a.year.forfeit and a.year.after only on the matching page.
class_name CardYearJumpPanel
extends CardPanel

const MonthUi = preload("res://scripts/cards/ui/month/month_ui.gd")
const KIND := &"year_jump"
const BOX_SIZE := Vector2(760, 380)

var _args: Dictionary = {}
var _lines: Array = []
var _index: int = 0
var _closed: bool = false
var _built: bool = false
var _page_label: Label
var _line_label: Label
var _body: Control
var _next_btn: Button
var _more_btn: Button


func bind(p_engine: CardEngineApi, p_bus: CardEventBus) -> void:
	super.bind(p_engine, p_bus)


func open(args: Dictionary) -> void:
	_args = args.duplicate(true)
	_lines = _read_lines()
	_index = 0
	_closed = false
	_build()
	_built = true
	_show_page()
	MonthUi.take_focus(self)


func refresh(_view: Dictionary) -> void:
	if not _built or _closed:
		return
	var lines := _read_lines()
	if _same_lines(lines, _lines):
		return
	_lines = lines
	if not _lines.is_empty() and _index > _lines.size() - 1:
		_index = _lines.size() - 1
	_show_page()


## Esc and the host both land here. Close only; year.next waits until the last page (section 7.8).
func dismiss() -> void:
	if _closed or not _built:
		return
	_closed = true
	_clear_anchors()
	close_requested.emit({})


func autoplay_step() -> bool:
	if _closed or not _built:
		return false
	_advance()
	return true


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_SPACE or ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER:
		_advance()
		accept_event()
	elif ke.keycode == KEY_ESCAPE:
		dismiss()
		accept_event()


# TODO(design): year_report rows have no contract field for which group they belong to.
# Recognize section when the fixture or engine sends forfeit/after/currency/contacts/faces.
# Otherwise keep file order, one row per page.
func _read_lines() -> Array:
	var out: Array = []
	if engine == null:
		return out
	var q = engine.query(&"year_report", {})
	if typeof(q) != TYPE_DICTIONARY:
		return out
	var raw = q.get("lines", [])
	if typeof(raw) != TYPE_ARRAY:
		return out
	for row in raw:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var key := str(row.get("key", ""))
		if key == "":
			continue
		var row_args = row.get("args", {})
		if typeof(row_args) != TYPE_DICTIONARY:
			row_args = {}
		var sec := str(row.get("section", ""))
		if not _known_section(sec):
			sec = ""
		out.append({"key": key, "args": row_args.duplicate(true), "section": sec})
	return out


func _known_section(sec: String) -> bool:
	return sec == "forfeit" or sec == "after" or sec == "currency" or sec == "contacts" or sec == "faces"


func _same_lines(a: Array, b: Array) -> bool:
	return JSON.stringify(a) == JSON.stringify(b)


func _build() -> void:
	MonthUi.clear(self)
	MonthUi.prepare(self)
	MonthUi.shade(self)
	# Reskin 10-22: a dark .modal like the other overlays; one line per page, a gold "next year" at the end.
	var frame := MonthUi.centred(BOX_SIZE)
	var box := MonthUi.modal(self, frame)
	var col := VBoxContainer.new()
	col.name = "Column"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 12)
	box.add_child(col)
	var title_ref := "c09.year.title"
	var title := MonthUi.label(CardText.ui(title_ref), MonthUi.TITLE_SIZE, true, CardText.is_draft(title_ref))
	title.name = "Heading"
	col.add_child(title)
	# Page counter at the top right of the sheet; a direct child (X01 reads the panel's "Page" node).
	_page_label = MonthUi.note("", false)
	_page_label.name = "Page"
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_page_label.size_flags_horizontal = Control.SIZE_FILL
	MonthUi.place(_page_label, frame.position + Vector2(frame.size.x - 38.0 - 260.0, 44.0), Vector2(260, 24))
	add_child(_page_label)
	_body = Control.new()
	_body.name = "YearBody"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.custom_minimum_size = Vector2(0, 150)
	col.add_child(_body)
	_line_label = MonthUi.label("", 18, false, false)
	_line_label.name = "Line"
	_line_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.add_child(_line_label)
	var row := HBoxContainer.new()
	row.name = "Buttons"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	# Mouse players page on with this button (keys only before: Space / Enter).
	_more_btn = MonthUi.button(CardText.ui("c09.btn.year_more"), "YearMore")
	_more_btn.pressed.connect(_advance)
	row.add_child(_more_btn)
	_next_btn = MonthUi.button(CardText.ui("c09.btn.next_year"), "NextYear", true)
	_next_btn.pressed.connect(_commit)
	row.add_child(_next_btn)


func _show_page() -> void:
	var n := maxi(_lines.size(), 1)
	var page_no := _index + 1
	if _lines.is_empty():
		page_no = 1
	var page_args := {"i": page_no, "n": n}
	_page_label.text = CardText.ui("c09.year.page", page_args)
	var draft_page := CardText.is_draft("c09.year.page")
	_page_label.add_theme_color_override("font_color", CardTheme.color(&"text_3" if draft_page else &"text_2"))
	var sec := ""
	var text := ""
	var draft := false
	if _index >= 0 and _index < _lines.size():
		var line: Dictionary = _lines[_index]
		var key := str(line.get("key", ""))
		text = CardText.ui(key, line.get("args", {}))
		draft = CardText.is_draft(key)
		sec = str(line.get("section", ""))
	_line_label.text = text
	_line_label.add_theme_color_override("font_color", CardTheme.color(MonthUi.ink(false, draft, false)))
	_body.set_meta("section", sec)
	_sync_anchor(sec)
	var last := _lines.is_empty() or _index >= _lines.size() - 1
	_next_btn.visible = last
	_more_btn.visible = not last


func _clear_anchors() -> void:
	if _body == null:
		return
	CardAnchors.unregister(&"a.year.forfeit", _body)
	CardAnchors.unregister(&"a.year.after", _body)


func _sync_anchor(sec: String) -> void:
	_clear_anchors()
	if sec == "forfeit":
		CardAnchors.register(&"a.year.forfeit", _body)
	elif sec == "after":
		CardAnchors.register(&"a.year.after", _body)


func _advance() -> void:
	if _closed:
		return
	if _lines.is_empty() or _index >= _lines.size() - 1:
		_commit()
		return
	_index += 1
	_show_page()


func _commit() -> void:
	if _closed:
		return
	if not _lines.is_empty() and _index < _lines.size() - 1:
		return
	_closed = true
	_clear_anchors()
	if engine != null:
		engine.send(&"year.next", {})
	close_requested.emit({})
