# Close-day confirm: list what still happens if the player ends the day, then send day.end once.
# Owner C08. Contract 1.2/1.3: the list never blocks the day; "back" sends nothing.
# Anchors a.endday.blocked and a.endday.gold_leave. Text from CardText, color from CardTheme.
# Exit teardown frees mini cards and clears anchors so day-walk tests do not leave RIDs.
class_name CardEndDayConfirm
extends CardPanel

const _DemandScript := preload("res://scripts/cards/ui/demand/demand_panel.gd")
const Chrome = preload("res://scripts/cards/ui/night/panel_chrome.gd")
const KIND := &"end_day"
const SHEET := Vector2(760, 620)   # max; the height follows the list (SHEET_MIN_H..620)
const SHEET_MIN_H := 300.0
const CHROME_H := 210.0   # frame + padding + title + note + buttons
const CARD_ROW_H := 100.0
const TEXT_ROW_H := 30.0
const ROW_GAP := 10

var _closed: bool = false
var _sent: bool = false
var _rows: Array = []
var _torn: bool = false
var _list_mark: Control = null
var _gold_mark: Control = null


var _pending: Dictionary = {}
## True only when the sheet offers the pending panel instead of a confirm (month open, see open()).
var _pending_only: bool = false


func _init() -> void:
	if _DemandScript == null:
		push_error("CardEndDayConfirm: demand script failed to load")


func open(args: Dictionary) -> void:
	_torn = false
	_closed = false
	_sent = false
	_rows = _read_rows(args)
	# b52: at month open (step begin_month) the engine still waits for a panel the player closed
	# (the month wheel). Say so, and offer to reopen it instead of a confirm that cannot pass.
	_pending = args.get("pending", {}) if typeof(args.get("pending")) == TYPE_DICTIONARY else {}
	var begin_month := str(args.get("step", "")) == "begin_month"
	_pending_only = begin_month and not _pending.is_empty()
	Chrome.prepare(self)
	_list_mark = null
	_gold_mark = null
	var col: VBoxContainer = Chrome.sheet(self, _sheet_size(_rows))
	var title_key := "c08.end.title_month" if begin_month else "c08.end.title"
	var title := Chrome.label(CardText.ui(title_key), Chrome.TITLE_SIZE, title_key)
	title.name = "Title"
	col.add_child(title)
	var note_key := "c08.end.note_month" if begin_month else "c08.end.note"
	var note := Chrome.note(CardText.ui(note_key), note_key)
	note.name = "Note"
	col.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "Rows"
	list.add_theme_constant_override("separation", ROW_GAP)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	# Guide anchors follow the real list and the real gold row (they scroll with the sheet).
	_list_mark = scroll
	CardAnchors.register(&"a.endday.blocked", scroll)
	for i in range(_rows.size()):
		var row: Dictionary = _rows[i]
		var line := _build_row(row, i)
		list.add_child(line)
		if str(row.get("kind", "")) == "gold_leave" and _gold_mark == null:
			_gold_mark = line
			CardAnchors.register(&"a.endday.gold_leave", line)
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_BEGIN
	buttons.add_theme_constant_override("separation", 12)
	col.add_child(buttons)
	var back := Chrome.button(CardText.ui("c08.btn.back"), "c08.btn.back")
	back.name = "BtnBack"
	back.pressed.connect(_back)
	buttons.add_child(back)
	if _pending_only:
		var go := Chrome.button(CardText.ui("c08.btn.to_pending"), "c08.btn.to_pending", true)
		go.name = "BtnPending"
		go.pressed.connect(_to_pending)
		buttons.add_child(go)
	# QA 10-25: the confirm stays at month open too (contract: the close-day button can always move on, an
	# unspun month wheel is spun from the incense table; W0/C01 next-day and X01 boot press it). It just
	# reads "open anyway" there instead of "close anyway".
	var confirm_key := "c08.btn.confirm_month" if begin_month else "c08.btn.confirm"
	var confirm := Chrome.button(CardText.ui(confirm_key), confirm_key, not _pending_only)
	confirm.name = "BtnConfirm"
	confirm.pressed.connect(_confirm)
	buttons.add_child(confirm)


## Prototype .modal: 680+ wide, as tall as the list needs, never past the overlay box (scrolls past that).
func _sheet_size(rows: Array) -> Vector2:
	var list_h := 0.0
	for row in rows:
		var has_card := typeof(row) == TYPE_DICTIONARY and str(row.get("uid", "")) != ""
		list_h += (CARD_ROW_H if has_card else TEXT_ROW_H) + ROW_GAP
	var h := CHROME_H + maxf(list_h, TEXT_ROW_H)
	return Vector2(SHEET.x, clampf(h, SHEET_MIN_H, SHEET.y))


func refresh(_view: Dictionary) -> void:
	pass


func autoplay_step() -> bool:
	if _closed or _sent or _torn:
		return false
	_confirm()
	return _sent


func dismiss() -> void:
	_back()


func _exit_tree() -> void:
	_teardown()


func _teardown() -> void:
	if _torn:
		return
	_torn = true
	if _list_mark != null and is_instance_valid(_list_mark):
		CardAnchors.unregister(&"a.endday.blocked", _list_mark)
	if _gold_mark != null and is_instance_valid(_gold_mark):
		CardAnchors.unregister(&"a.endday.gold_leave", _gold_mark)
	_list_mark = null
	_gold_mark = null
	# Free children now so CardWidget textures are not left after remove_child paths.
	while get_child_count() > 0:
		var c: Node = get_child(0)
		remove_child(c)
		c.queue_free()
	engine = null
	bus = null


func _read_rows(args: Dictionary) -> Array:
	var raw = args.get("items", null) if args.has("items") else null
	if raw == null and engine != null:
		var preview: Dictionary = engine.query(&"day.end_preview", {})
		raw = preview.get("items", [])
	if typeof(raw) != TYPE_ARRAY:
		return []
	var out: Array = []
	for item in raw:
		if typeof(item) == TYPE_DICTIONARY:
			out.append(item)
	return out


func _build_row(row: Dictionary, index: int) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.name = "EndRow%d" % index
	line.set_meta("kind", str(row.get("kind", "")))
	line.add_theme_constant_override("separation", 12)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var uid := str(row.get("uid", ""))
	if uid != "":
		var card := CardWidget.new()
		card.name = "Mini%d" % index
		card.bus = bus
		card.set_size_mode(&"mini")
		card.set_card(_card_view(uid, str(row.get("kind", "")) == "gold_leave"))
		card.pressed.connect(_open_uid)
		line.add_child(card)
	line.add_child(Chrome.dot())
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(text)
	var key := str(row.get("consequence_key", ""))
	var line_args: Dictionary = row.get("args", {}) if typeof(row.get("args")) == TYPE_DICTIONARY else {}
	var kind := str(row.get("kind", ""))
	var body := Chrome.label(CardText.t(key, line_args), 16, key)
	body.name = "Consequence"
	if kind == "wait":
		# Not a loss: the dimmer --text-2 ink on the dark sheet (was ink_soft on paper).
		body.add_theme_color_override("font_color", CardTheme.color(&"text_2"))
	text.add_child(body)
	if kind == "gold_leave":
		var reminder := Chrome.label(CardText.ui("c08.gold.reminder"), 14, "c08.gold.reminder")
		reminder.name = "GoldNote"
		reminder.add_theme_color_override("font_color", CardTheme.color(&"gold_hi"))
		text.add_child(reminder)
	elif kind == "wait":
		var wait := Chrome.note(CardText.ui("c08.end.wait"), "c08.end.wait")
		wait.name = "WaitNote"
		wait.add_theme_color_override("font_color", CardTheme.color(&"text_3"))
		text.add_child(wait)
	return line


func _card_view(uid: String, gold_fallback: bool) -> Dictionary:
	if engine != null:
		var cv: Dictionary = engine.query(&"card", {"uid": uid})
		if cv.has("def"):
			if str(cv.get("uid", "")) == "":
				cv["uid"] = uid
			return cv
	return {"uid": uid, "def": "", "type": "person", "zone": "hand", "art": "", "gold": gold_fallback,
		"must_resolve": true, "expires_in": -1, "actions": []}


func _open_uid(uid: String) -> void:
	if _closed or _torn or uid == "":
		return
	_closed = true
	close_requested.emit({"open_uid": uid})


func _back() -> void:
	if _closed or _torn:
		close_requested.emit({})
		return
	_closed = true
	close_requested.emit({})


func _to_pending() -> void:
	if _closed or _torn:
		return
	_closed = true
	close_requested.emit({"next": _pending})


## Enter: the sheet's primary button (reopen the pending month wheel at month open, else confirm).
func _primary() -> void:
	if _pending_only:
		_to_pending()
	else:
		_confirm()


func _confirm() -> void:
	# QA 10-25: confirm always sends day.end {confirm:true}. The b52 version turned it into "reopen the
	# pending panel" whenever args.pending was set (its BtnConfirm check never found the nested button), so
	# on street / prison days and at month open the close-day button could not move on.
	if _closed or _sent or _torn or engine == null:
		return
	_sent = true
	var result: Dictionary = engine.send(&"day.end", {"confirm": true})
	if not bool(result.get("ok", false)):
		_sent = false
		return
	_closed = true
	close_requested.emit({})


func _unhandled_input(event: InputEvent) -> void:
	if _closed or _torn or not Chrome.is_front(self):
		return
	var code := Chrome.pressed_key(event)
	if code < 0:
		return
	if code == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_back()
	elif code == KEY_ENTER or code == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		_primary()
