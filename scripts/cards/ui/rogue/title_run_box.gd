# Rogue v1 box on the title (bottom right, 744,400 456x280): which ledger "open shop" starts, the seed field and
# "another one", the openings (only when two or more are unlocked), and the shelf of closed ledgers: one spine per
# ledger (24x100, oldest left, at most 16), coloured by how it closed (ending gold, prison seal, otherwise wood);
# hovering a spine shows "ledger n" and its chronicle line; an empty shelf says what will stand there. While a
# ledger is still open (data open_no > 0) the head line says so: "open shop" closes it and starts the next one.
# Mouse only, except the seed field (a click gives it focus; then CardTitle hands it every key but Enter / Esc). The data and the actions belong to the shell (RG5):
# CardTitle.set_rogue(data) fills it; the box emits reseed_pressed / opening_changed and CardTitle forwards them as
# chose(&"reseed") / chose(&"opening"). No class_name (preload). Owner RG4.
# Contract: docs/cards/rogue/ROGUE_V1.md sections 7.5, 8.3, 11.
extends Control

const Ui = preload("res://scripts/cards/ui/rogue/rogue_ui.gd")

signal reseed_pressed
signal opening_changed(id: String)

const RECT := Rect2(744, 400, 456, 280)
const PAD := 16.0
const RUN_Y := 12.0
const SEED_Y := 44.0
const OPEN_Y := 88.0
const SHELF_Y := 132.0
const SPINE_Y := 156.0
const SPINE := Vector2(24, 100)
const SPINE_GAP := 4.0
const MAX_SPINES := 16
const READ_Y := 260.0
const FIELD := Vector2(180, 32)
const LABEL_W := 44.0
const SEED_MAX := 24
## The opening buttons may run into the box's padding but stop this far from its right edge.
const OPEN_EDGE := 6.0
const DEFAULT_OPENING := "og.default"
const SPINE_KEYS := {"ending": &"gold", "prison": &"seal"}
const SPINE_INKS := {"ending": &"ink"}

## Notice keys already shown by any title box this session ("shown once", section 7.5).
static var _notices_seen: Dictionary = {}

var _data: Dictionary = {}
var _seed_field: LineEdit
var _reseed: Button
var _opening: String = DEFAULT_OPENING
var _last_seed: int = -1
var _content: Control
var _open_buttons: Dictionary = {}
var _spines: Array = []
var _read_row: HBoxContainer
var _read_no: Label
var _read_line: Label
var _notice_key: String = ""


func _init() -> void:
	name = "RunBox"
	position = RECT.position
	size = RECT.size
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := Panel.new()
	back.name = "Back"
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.size = RECT.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = CardTheme.with_alpha(&"scene_void", 0.72)
	sb.border_color = CardTheme.with_alpha(&"line", 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	back.add_theme_stylebox_override("panel", sb)
	add_child(back)
	_seed_field = LineEdit.new()
	_seed_field.name = "Seed"
	_seed_field.max_length = SEED_MAX
	_seed_field.focus_mode = Control.FOCUS_CLICK
	_seed_field.select_all_on_focus = true
	_seed_field.tooltip_text = CardText.ui("rg4.title.seed_tip")
	_seed_field.position = Vector2(PAD + LABEL_W, SEED_Y)
	_seed_field.size = FIELD
	_seed_field.custom_minimum_size = FIELD
	add_child(_seed_field)


func set_data(data: Dictionary) -> void:
	_data = data.duplicate(true)
	var seed_value := int(_data.get("seed", 0))
	if seed_value != _last_seed or _seed_field.text.strip_edges() == "":
		_seed_field.text = str(seed_value) if seed_value > 0 else ""
	_last_seed = seed_value
	_seed_field.tooltip_text = CardText.ui("rg4.title.seed_tip")
	_opening = str(_data.get("opening", DEFAULT_OPENING))
	if _opening == "":
		_opening = DEFAULT_OPENING
	if _content != null:
		remove_child(_content)
		_content.queue_free()
	_content = Control.new()
	_content.name = "Content"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.size = RECT.size
	add_child(_content)
	move_child(_seed_field, -1)
	_head()
	_openings()
	_shelf()
	_notice(str(_data.get("notice_key", "")))


func seed_text() -> String:
	return _seed_field.text


func opening_id() -> String:
	return _opening


func seed_field() -> LineEdit:
	return _seed_field


func seed_has_focus() -> bool:
	return _seed_field != null and _seed_field.has_focus()


func reseed_button() -> Button:
	return _reseed


func opening_buttons() -> Dictionary:
	return _open_buttons


func spines() -> Array:
	return _spines


## The hover line under the shelf: [book number label, chronicle label]; hidden when no spine is hovered.
func read_labels() -> Array:
	return [_read_no, _read_line]


func notice_key() -> String:
	return _notice_key


func _head() -> void:
	var n := int(_data.get("run_no", 1))
	var open_no := int(_data.get("open_no", 0))
	var run_key := "rg4.title.run_open" if open_no > 0 else "rg4.title.run_no"
	var run := Ui.label(CardText.ui(run_key, {"n": n, "open": open_no}), 16, &"gold_hi", &"bold", CardText.is_draft(run_key))
	run.name = "RunNo"
	run.position = Vector2(PAD, RUN_Y)
	_content.add_child(run)
	_content.add_child(_tag("SeedLabel", "rg4.title.seed", SEED_Y))
	_reseed = Button.new()
	_reseed.name = "Reseed"
	_reseed.text = CardText.ui("rg4.title.reseed")
	_reseed.theme_type_variation = &"SmallButton"
	_reseed.focus_mode = Control.FOCUS_NONE
	_reseed.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_reseed.position = Vector2(PAD + LABEL_W + FIELD.x + 10.0, SEED_Y)
	_reseed.size = Vector2(0, FIELD.y)
	_reseed.pressed.connect(func() -> void: reseed_pressed.emit())
	_content.add_child(_reseed)
	_reseed.reset_size()
	_reseed.size.y = FIELD.y


func _tag(node_name: String, key: String, y: float) -> Label:
	var l := Ui.label(CardText.ui(key), 14, &"text_2", &"bold", CardText.is_draft(key))
	l.name = node_name
	l.position = Vector2(PAD, y + 6.0)
	l.size = Vector2(LABEL_W, 20)
	return l


## Opening buttons, only when at least two openings are unlocked. The chosen one is gold.
func _openings() -> void:
	_open_buttons = {}
	var ids: Array = []
	for row in Ui.array(_data.get("openings", [])):
		if typeof(row) == TYPE_DICTIONARY and bool(row.get("unlocked", false)) and str(row.get("id", "")) != "":
			ids.append(str(row["id"]))
	if not ids.has(_opening):
		_opening = DEFAULT_OPENING if ids.is_empty() or ids.has(DEFAULT_OPENING) else str(ids[0])
	if ids.size() < 2:
		return
	_content.add_child(_tag("OpeningLabel", "rg4.title.opening", OPEN_Y))
	var x := PAD + LABEL_W
	for id in ids:
		var b := Button.new()
		b.name = "Opening_" + str(id).replace(".", "_")
		b.text = CardText.ui("rg5.opening." + str(id).trim_prefix("og."))
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.position = Vector2(x, OPEN_Y)
		b.set_meta("opening", id)
		b.pressed.connect(_pick_opening.bind(str(id)))
		_content.add_child(b)
		_paint_opening(b, id == _opening)
		b.reset_size()
		# Long opening names never run past the box: the button stops at its edge, the words get an ellipsis.
		var room := RECT.size.x - OPEN_EDGE - x
		if b.size.x > room:
			b.clip_text = true
			b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			b.custom_minimum_size = Vector2.ZERO
			b.size.x = maxf(room, FIELD.y)
		b.size.y = FIELD.y
		x += b.size.x + 8.0
		_open_buttons[id] = b


func _pick_opening(id: String) -> void:
	if id == _opening:
		return
	_opening = id
	for key in _open_buttons:
		_paint_opening(_open_buttons[key], key == id)
	opening_changed.emit(id)


func _paint_opening(b: Button, on: bool) -> void:
	var top := &"btn_primary_top" if on else &"btn_top"
	var bot := &"btn_primary_bot" if on else &"btn_bot"
	var edge := &"btn_primary_edge" if on else &"btn_edge"
	var normal := CardTheme.button_style(top, bot, edge, 10.0, 4.0, 5)
	var hover := CardTheme.button_style(&"btn_primary_hover_top" if on else &"btn_hover_top",
		&"btn_primary_hover_bot" if on else &"btn_top", edge if on else &"gold_deep", 10.0, 4.0, 5)
	for s in [&"normal", &"focus", &"disabled"]:
		b.add_theme_stylebox_override(s, normal)
	for s in [&"hover", &"pressed", &"hover_pressed"]:
		b.add_theme_stylebox_override(s, hover)
	var ink := CardTheme.color(&"btn_primary_ink") if on else CardTheme.color(&"hud_ink")
	var lit := CardTheme.color(&"btn_primary_ink") if on else CardTheme.color(&"gold_pale")
	for c in [&"font_color", &"font_focus_color", &"font_disabled_color"]:
		b.add_theme_color_override(c, ink)
	for c in [&"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		b.add_theme_color_override(c, lit)
	b.add_theme_font_override("font", CardTheme.font_body_bold() if on else CardTheme.font_body())
	b.add_theme_font_size_override("font_size", 14)
	b.set_meta("on", on)


## Closed ledgers, oldest left; at most the newest 16.
func _shelf() -> void:
	_spines = []
	_content.add_child(_tag("ShelfLabel", "rg4.title.shelf", SHELF_Y - 6.0))
	var rows: Array = []
	for row in Ui.array(_data.get("shelf", [])):
		if typeof(row) == TYPE_DICTIONARY:
			rows.append(row)
	if rows.size() > MAX_SPINES:
		rows = rows.slice(rows.size() - MAX_SPINES)
	var width := float(rows.size()) * SPINE.x + float(maxi(rows.size() - 1, 0)) * SPINE_GAP
	var x0 := PAD if width <= RECT.size.x - PAD * 2.0 else floorf((RECT.size.x - width) * 0.5)
	if rows.is_empty():
		var empty := Ui.label(CardText.ui("rg4.title.shelf_empty"), 14, &"text_2", &"body",
			CardText.is_draft("rg4.title.shelf_empty"))
		empty.name = "ShelfEmpty"
		empty.position = Vector2(PAD, SPINE_Y + 8.0)
		_content.add_child(empty)
	for i in rows.size():
		var spine := _spine(rows[i], i)
		spine.position = Vector2(x0 + float(i) * (SPINE.x + SPINE_GAP), SPINE_Y)
		_content.add_child(spine)
		_spines.append(spine)
	_read_row = Ui.row_box(6)
	_read_row.name = "Read"
	_read_row.position = Vector2(PAD, READ_Y)
	_read_row.size = Vector2(RECT.size.x - PAD * 2.0, 20)
	_read_row.visible = false
	_content.add_child(_read_row)
	_read_no = Ui.label("", 14, &"gold_hi", &"bold")
	_read_no.name = "BookNo"
	_read_row.add_child(_read_no)
	_read_row.add_child(_dot())
	_read_line = Ui.line("", 14, &"hud_ink", 0.0)
	_read_line.name = "Chronicle"
	_read_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_read_row.add_child(_read_line)


func _spine(row: Dictionary, i: int) -> Panel:
	var reason := str(row.get("reason", ""))
	var p := Panel.new()
	p.name = "Spine%d" % i
	p.size = SPINE
	p.custom_minimum_size = SPINE
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_HELP
	var sb := StyleBoxFlat.new()
	sb.bg_color = CardTheme.color(SPINE_KEYS.get(reason, &"wood"))
	sb.border_color = CardTheme.color(&"wood_dark")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.set_meta("no", int(row.get("no", 0)))
	p.set_meta("reason", reason)
	for y in [8.0, SPINE.y - 12.0]:
		var band := ColorRect.new()
		band.color = CardTheme.with_alpha(&"ink", 0.3)
		band.position = Vector2(2, y)
		band.size = Vector2(SPINE.x - 4.0, 3)
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(band)
	var key := "rg4.title.book_no"
	var t := Ui.label(CardText.ui(key, {"n": int(row.get("no", 0))}), 14, SPINE_INKS.get(reason, &"paper"), &"body",
		CardText.is_draft(key))
	t.name = "No"
	t.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("line_spacing", -5)
	t.position = Vector2(4, 14)
	t.size = Vector2(SPINE.x - 8.0, SPINE.y - 28.0)
	t.custom_minimum_size = t.size
	p.add_child(t)
	p.mouse_entered.connect(_read.bind(row))
	p.mouse_exited.connect(_unread)
	return p


func _read(row: Dictionary) -> void:
	if _read_row == null:
		return
	_read_no.text = CardText.ui("rg4.title.book_no", {"n": int(row.get("no", 0))})
	var args := Ui.dict(row.get("args", {}))
	_read_line.text = CardText.ui(str(row.get("key", "")), args)
	_read_row.visible = true


func _unread() -> void:
	if _read_row != null:
		_read_row.visible = false


func _dot() -> Control:
	var d := Control.new()
	d.custom_minimum_size = Vector2(8, 20)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink := CardTheme.color(&"gold_deep")
	d.draw.connect(func() -> void: d.draw_circle(Vector2(4, 10), 2.0, ink))
	return d


## A notice for the shell (profile reset ...): above the box, once per session.
func _notice(key: String) -> void:
	if key == "" or (_notices_seen.has(key) and _notice_key != key):
		return
	_notices_seen[key] = true
	_notice_key = key
	var l := Ui.pill(CardText.ui(key), &"seal_dark", &"paper", 14, CardText.is_draft(key))
	l.name = "Notice"
	l.position = Vector2(0, -34)
	_content.add_child(l)
