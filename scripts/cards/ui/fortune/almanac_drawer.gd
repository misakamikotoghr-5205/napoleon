# Almanac drawer (right drawer): today's suitable and avoid actions with a mark on the ones already done,
# this month's fortune segment name, and the lots already drawn (verse only). Read-only, sends nothing.
# Words come from CardText: g05.almanac.<action> (G05), <segment>#title, <lot>#verse, c07.strip.* and c07.drawer.*.
# No rule text: the drawer never says whether following the almanac pays off (DESIGN 9.4; task card C07).
# Owner C07. Kind almanac, drawer_r. Contract: docs/cards/CARDS_INTERFACES.md sections 7.8, 7.11.8, 9.4.
# Reskin QA 10-25 (web prototype .drawer almanac): the rows sit on the dark drawer like the other drawers
# (light text, gold section heads); today's suitable/avoid words are a paper card with a seal-red top band
# (brush yi in green, ji in dark red, ink words). Content starts under the frame's title row (drawer_host.HEAD_H)
# and the scroll area stops above the close-day plate, which the host draws over right drawers.
class_name CardAlmanacDrawer
extends CardPanel

const Style = preload("res://scripts/cards/ui/fortune/fortune_style.gd")
const Strip = preload("res://scripts/cards/ui/fortune/almanac_strip.gd")
const DrawerHost = preload("res://scripts/cards/ui/table/drawer_host.gd")

## Inside of the right drawer frame: 16 px padding, under the title row the host draws and its 1px rule (7.11.8).
const INNER := Vector2(388, 630)
const PAD := 16.0
const TITLE_ROW := DrawerHost.HEAD_H + 1.0
const PREFIX_W := 48.0
const WORD_H := 26.0
const PREFIX_H := 34.0
const MAX_LOTS := 8
## Gap kept above the close-day plate (CardLayout.END_DAY) at the bottom of the scroll area.
const FOOT_GAP := 8.0

var _root: Panel
var _list: VBoxContainer
var _today: Control
var _closed: bool = false
var _looked: bool = false


func _ready() -> void:
	# The host pins this panel over the whole screen; only the content box takes the mouse,
	# so the drawer frame's close button and the scrim stay clickable.
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


## Look once, then close (section 7.11.8). Never acts for the player.
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


func _ensure() -> void:
	if _root != null:
		return
	var rect := CardLayout.DRAWER_R
	_root = Panel.new()
	_root.name = "AlmanacBox"
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
	_list = VBoxContainer.new()
	_list.name = "Rows"
	_list.custom_minimum_size = Vector2(INNER.x - 12.0, 0)
	_list.add_theme_constant_override("separation", 8)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_list)


func _refill(view: Dictionary) -> void:
	_ensure()
	if _today != null and is_instance_valid(_today):
		CardAnchors.unregister(&"a.almanac", _today)
	_today = null
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var notice = view.get("notice", {})
	if typeof(notice) != TYPE_DICTIONARY:
		notice = {}
	_today_section(_dict(notice.get("almanac", {})))
	_fortune_section(str(notice.get("fortune", "")))
	_lots_section(_array(view.get("lots", [])))


func _today_section(alm: Dictionary) -> void:
	_list.add_child(_heading("c07.drawer.title"))
	var card := PanelContainer.new()
	card.name = "TodayCard"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _paper_style())
	_list.add_child(card)
	var box := VBoxContainer.new()
	box.name = "Today"
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var done := _array(alm.get("done", []))
	var yi := _array(alm.get("yi", []))
	var ji := _array(alm.get("ji", []))
	if yi.is_empty() and ji.is_empty():
		var none := _none()
		_ink(none, &"ink_soft", false)
		box.add_child(none)
	else:
		box.add_child(_action_row("Yi", "c07.strip.yi", yi, done))
		box.add_child(_action_row("Ji", "c07.strip.ji", ji, done))
	_today = box
	CardAnchors.register(&"a.almanac", box)


func _fortune_section(segment: String) -> void:
	_list.add_child(_heading("c07.drawer.fortune"))
	if segment == "":
		_list.add_child(_none())
		return
	var ref := segment + "#title"
	var l := Style.label(CardText.t(ref), CardTheme.font_size(&"body"), CardText.is_draft(ref))
	l.name = "Fortune"
	l.custom_minimum_size = Vector2(INNER.x - 16.0, WORD_H)
	_list.add_child(l)


func _lots_section(lots: Array) -> void:
	_list.add_child(_heading("c07.drawer.lots"))
	var ids: Array = []
	for row in lots:
		var lot := str(row.get("lot", "")) if typeof(row) == TYPE_DICTIONARY else str(row)
		if lot != "":
			ids.append(lot)
	if ids.is_empty():
		_list.add_child(_none())
		return
	# Newest first; only the latest few fit the drawer.
	ids.reverse()
	for i in range(mini(ids.size(), MAX_LOTS)):
		var lot: String = ids[i]
		var verse := Style.label(CardText.card(lot, "verse"), CardTheme.font_size(&"body"), CardText.is_draft(lot + "#verse"))
		verse.name = "Lot%d" % i
		verse.clip_text = false
		verse.custom_minimum_size = Vector2(INNER.x - 16.0, 0)
		_list.add_child(verse)


func _action_row(node_name: String, prefix_key: String, actions: Array, done: Array) -> Control:
	var row := HBoxContainer.new()
	row.name = node_name
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var draft := CardText.is_draft(prefix_key)
	var prefix := Style.label(CardText.ui(prefix_key), CardTheme.font_size(&"body_lg"), draft)
	# Brush yi / ji on the paper card (prototype .almcard: suitable green, avoid seal red).
	prefix.add_theme_font_override("font", CardTheme.font_title())
	prefix.add_theme_font_size_override("font_size", CardTheme.font_size(&"title_sm"))
	_ink(prefix, &"ledger_in" if node_name == "Yi" else &"seal_dark", draft)
	prefix.autowrap_mode = TextServer.AUTOWRAP_OFF
	prefix.clip_text = false
	prefix.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prefix.custom_minimum_size = Vector2(PREFIX_W, PREFIX_H)
	prefix.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(prefix)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 4)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(flow)
	for a in actions:
		if typeof(a) != TYPE_STRING and typeof(a) != TYPE_STRING_NAME:
			continue
		flow.add_child(_action(str(a), _listed(str(a), done)))
	return row


func _action(act: String, marked: bool) -> Control:
	var key := "g05.almanac." + act
	var item := HBoxContainer.new()
	item.set_meta("action", act)
	item.add_theme_constant_override("separation", 2)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var word := Style.label(CardText.ui(key), CardTheme.font_size(&"body"), CardText.is_draft(key))
	_ink(word, &"ink", CardText.is_draft(key))
	word.autowrap_mode = TextServer.AUTOWRAP_OFF
	word.clip_text = false
	word.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	word.custom_minimum_size = Vector2(0, WORD_H)
	item.add_child(word)
	if marked:
		var mark := Strip.DoneMark.new()
		mark.name = "DoneMark"
		mark.custom_minimum_size = Vector2(12, 14)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(mark)
	return item


## Section head: gold bold body text (prototype .sec h3), on the dark drawer.
func _heading(key: String) -> Label:
	var draft := CardText.is_draft(key)
	var l := Style.label(CardText.ui(key), CardTheme.font_size(&"body"), draft)
	l.name = "Head_" + key.get_slice(".", key.get_slice_count(".") - 1)
	l.add_theme_font_override("font", CardTheme.font_body_bold())
	_ink(l, &"gold_hi", draft)
	l.clip_text = false
	l.custom_minimum_size = Vector2(INNER.x - 16.0, 28)
	return l


func _none() -> Label:
	var l := Style.label(CardText.ui("c07.drawer.none"), CardTheme.font_size(&"min"), CardText.is_draft("c07.drawer.none"))
	_ink(l, &"text_2", CardText.is_draft("c07.drawer.none"))
	l.clip_text = false
	l.custom_minimum_size = Vector2(INNER.x - 16.0, WORD_H)
	return l


## Text colour by role; draft text (no words written yet) stays the muted placeholder tone.
func _ink(l: Label, key: StringName, draft: bool) -> void:
	l.add_theme_color_override("font_color", CardTheme.color(&"text_3" if draft else key))


## Today's card: paper with a seal-red band on top (prototype almanac card).
func _paper_style() -> StyleBoxFlat:
	var sb := CardTheme.paper_card_style()
	sb.border_color = CardTheme.color(&"seal")
	sb.border_width_top = 6
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 10.0
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	return sb


func _listed(act: String, done: Array) -> bool:
	for d in done:
		if str(d) == act:
			return true
	return false


func _dict(v) -> Dictionary:
	return v if typeof(v) == TYPE_DICTIONARY else {}


func _array(v) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []
