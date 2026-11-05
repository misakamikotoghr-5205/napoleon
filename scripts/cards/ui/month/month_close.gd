# Month-close ledger: interest, expenses, tickets, goal results, neighborhood verdict.
# Each report row is CardText.ui(key, args). Money appears only inside those args.
# Owner C09. Contract: docs/cards/CARDS_INTERFACES.md section 3.3 C09, 7.8, 7.11.
# Overlay on the night counter (C01 draws the scene). Esc / dismiss() closes and sends nothing.
# Anchor a.mclose.accounts while the ledger block is on screen.
class_name CardMonthClose
extends CardPanel

const MonthUi = preload("res://scripts/cards/ui/month/month_ui.gd")
const KIND := &"month_close"
const BOX_W := 760.0
const BOX_MIN_H := 400.0
const CHROME_H := 300.0   # frame, pictures, title, note, goals heading, button
const PICTURES := ["prop.ledger", "prop.abacus"]
const PICTURE_K := 3

var _args: Dictionary = {}
var _view: Dictionary = {}
var _closed: bool = false
var _built: bool = false
var _accounts: VBoxContainer
var _goal_box: VBoxContainer
var _next_btn: Button
var _scroll: ScrollContainer


func bind(p_engine: CardEngineApi, p_bus: CardEventBus) -> void:
	super.bind(p_engine, p_bus)


func open(args: Dictionary) -> void:
	_args = args.duplicate(true)
	_view = engine.view().duplicate(true) if engine != null else {}
	_closed = false
	_build()
	_built = true
	_refill()
	MonthUi.take_focus(self)


func refresh(view: Dictionary) -> void:
	_view = view.duplicate(true)
	if not _built or _closed:
		return
	_refill()


## Esc and the host both land here. Close only; month.next stays on the button (section 7.8).
func dismiss() -> void:
	if _closed or not _built:
		return
	_closed = true
	if _accounts != null:
		CardAnchors.unregister(&"a.mclose.accounts", _accounts)
	close_requested.emit({})


func autoplay_step() -> bool:
	if _closed or not _built:
		return false
	_next_month()
	return true


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_SPACE or ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER:
		_next_month()
		accept_event()
	elif ke.keycode == KEY_ESCAPE:
		dismiss()
		accept_event()


func _build() -> void:
	MonthUi.clear(self)
	MonthUi.prepare(self)
	MonthUi.shade(self)
	# Prototype .ledgerbook (week settle): paper book, pictures on top, brush seal-red title, ink rows.
	# The rows scroll inside a fixed box so NextMonth always stays on screen (b01: 9 report lines and
	# 3 goals used to push it below y 720).
	var box := MonthUi.book(self, MonthUi.centred(_box_size()))
	var col := VBoxContainer.new()
	col.name = "Column"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 10)
	box.add_child(col)
	_add_pictures(col)
	var title_ref := "c09.close.title"
	var title := MonthUi.label(CardText.ui(title_ref), MonthUi.TITLE_SIZE, true, CardText.is_draft(title_ref), true)
	title.name = "Title"
	col.add_child(title)
	var note_ref := "c09.close.note"
	col.add_child(MonthUi.note(CardText.ui(note_ref), CardText.is_draft(note_ref), true))
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(_scroll)
	var inner := VBoxContainer.new()
	inner.name = "Inner"
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 16)
	_scroll.add_child(inner)
	_accounts = VBoxContainer.new()
	_accounts.name = "Accounts"
	_accounts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_accounts.add_theme_constant_override("separation", 0)
	_accounts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(_accounts)
	CardAnchors.register(&"a.mclose.accounts", _accounts, _accounts_rect)
	_goal_box = VBoxContainer.new()
	_goal_box.name = "Goals"
	_goal_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal_box.add_theme_constant_override("separation", 8)
	_goal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(_goal_box)
	_next_btn = MonthUi.button(CardText.ui("c09.btn.next_month"), "NextMonth", true)
	_next_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_next_btn.pressed.connect(_next_month)
	col.add_child(_next_btn)


## As tall as the report needs (rows about 30 px, goals about 64), never past the overlay box.
func _box_size() -> Vector2:
	var n := _report_lines().size()
	var goals = _view.get("goals", [])
	var g := (goals as Array).size() if typeof(goals) == TYPE_ARRAY else 0
	var h := CHROME_H + float(n) * 31.0 + 48.0 + float(g) * 64.0
	return Vector2(BOX_W, clampf(h, BOX_MIN_H, CardLayout.OVERLAY_MAX.size.y))


## Ledger and abacus pictures (prototype 120x78 / 156x66 = x3). Skipped when the art is missing.
func _add_pictures(col: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "Pictures"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	for id in PICTURES:
		if CardArt.is_missing(id):
			continue
		var base := CardArt.base_size(id)
		if base.x <= 0 or base.y <= 0:
			continue
		var pic := TextureRect.new()
		pic.texture = CardArt.texture(id)
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_SCALE
		pic.custom_minimum_size = Vector2(base * PICTURE_K)
		pic.size_flags_vertical = Control.SIZE_SHRINK_END
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pic)
	if row.get_child_count() > 0:
		col.add_child(row)
	else:
		row.free()


## The accounts block as far as it shows inside the scroll window (guide highlight).
func _accounts_rect() -> Rect2:
	if _accounts == null or not is_instance_valid(_accounts):
		return Rect2()
	var r := _accounts.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, _accounts.size)
	if _scroll != null and is_instance_valid(_scroll):
		var view := _scroll.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, _scroll.size)
		r = r.intersection(view)
	return r


func _refill() -> void:
	_clear_box(_accounts)
	var lines := _report_lines()
	for line in lines:
		if typeof(line) != TYPE_DICTIONARY:
			continue
		var key := str(line.get("key", ""))
		if key == "":
			continue
		var row_args = line.get("args", {})
		if typeof(row_args) != TYPE_DICTIONARY:
			row_args = {}
		var lab := MonthUi.label(CardText.ui(key, row_args), 16, false, CardText.is_draft(key), true)
		lab.set_meta("line_key", key)
		_accounts.add_child(_ruled(lab))
	_clear_box(_goal_box)
	var title_ref := "c09.goals.title"
	var head := MonthUi.label(CardText.ui(title_ref), 24, true, CardText.is_draft(title_ref), true)
	head.name = "GoalsTitle"
	_goal_box.add_child(head)
	var goals = _view.get("goals", [])
	if typeof(goals) != TYPE_ARRAY:
		return
	for g in goals:
		if typeof(g) != TYPE_DICTIONARY:
			continue
		if str(g.get("id", "")) == "":
			continue
		_goal_box.add_child(_goal_row(g))


## One ledger line: ink text over a faint rule (the prototype's two-column table rows).
func _ruled(lab: Label) -> Control:
	var cell := PanelContainer.new()
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rule := StyleBoxFlat.new()
	rule.bg_color = Color.TRANSPARENT
	rule.border_color = CardTheme.with_alpha(&"ink_3", 0.3)
	rule.border_width_bottom = 1
	rule.content_margin_top = 4.0
	rule.content_margin_bottom = 4.0
	cell.add_theme_stylebox_override("panel", rule)
	cell.add_child(lab)
	return cell


func _goal_row(g: Dictionary) -> Control:
	var id := str(g.get("id", ""))
	var row := VBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 2)
	if id == "":
		return row
	row.set_meta("goal_id", id)
	row.set_meta("main", bool(g.get("main", false)))
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 10)
	row.add_child(head)
	var title_ref := id + "#title"
	var title := MonthUi.label(CardText.t(title_ref), 17, false, CardText.is_draft(title_ref), true)
	title.add_theme_font_override("font", CardTheme.font_body_bold())
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title.autowrap_mode = TextServer.AUTOWRAP_OFF   # shrunk in a row, a wrapping label wraps per glyph
	head.add_child(title)
	if bool(g.get("main", false)):
		head.add_child(MonthUi.chip(CardText.ui("c09.goals.main"), &"seal_dark", &"seal_rim"))
	var st := str(g.get("status", ""))
	var field := ""
	if st == "done":
		field = id + "#done"
		head.add_child(MonthUi.chip(CardText.ui("c09.goals.done"), &"ledger_in", &"paper"))
	elif st == "failed":
		field = id + "#failed"
		head.add_child(MonthUi.chip(CardText.ui("c09.goals.failed"), &"ink_3", &"paper"))
	if field != "":
		row.set_meta("status", st)
		row.add_child(MonthUi.note(CardText.t(field), CardText.is_draft(field), true))
	return row


func _report_lines() -> Array:
	if engine == null:
		return []
	var q = engine.query(&"month_report", {})
	if typeof(q) != TYPE_DICTIONARY:
		return []
	var lines = q.get("lines", [])
	return lines if typeof(lines) == TYPE_ARRAY else []


func _clear_box(box: Node) -> void:
	if box == null:
		return
	var kids := box.get_children()
	for c in kids:
		box.remove_child(c)
		c.free()


func _next_month() -> void:
	if _closed:
		return
	_closed = true
	if _accounts != null:
		CardAnchors.unregister(&"a.mclose.accounts", _accounts)
	if engine != null:
		engine.send(&"month.next", {})
	close_requested.emit({})
