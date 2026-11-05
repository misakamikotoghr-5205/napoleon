# Household goods as the right drawer (388x630): five estates, pawn money, monthly interest as a sum, redeem.
# Owner C11. Contract 1.3 §7.11.8. Anchors: a.estate.list, a.estate.mortgage.
# Text via CardText, color via CardTheme. Closing sends no command.
# TODO(design): guide teacher for mortgage stays "" (contract §7.10.10 conflict c).
# Reskin 10-22 (prototype 36_drawer_assets; b19): the block sits inside the right drawer frame (not at the screen's
# top-left); a money box on top (coin, amount, currency), a gold section heading, then one row per estate:
# picture, name + status pill, "pawn for n / monthly interest m", one line of copy, and a small button.
# The frame's own 合上 (and Esc) closes it, so there is no second close button in here.
class_name CardEstatePanel
extends CardPanel

const Ui = preload("res://scripts/cards/ui/ladder/ladder_ui.gd")
const Kit = preload("res://scripts/cards/ui/slots/drawer_kit.gd")
const KIND := &"estates"

var _args: Dictionary = {}
var _chrome := false
var _grab := true
var _closed := false
var _body: VBoxContainer
var _list: VBoxContainer
var _reason: Label
var _money_n: Label
var _money_unit: Label


func bind(p_engine: CardEngineApi, p_bus: CardEventBus) -> void:
	super.bind(p_engine, p_bus)
	if bus != null and not bus.view_changed.is_connected(_on_view_changed):
		bus.view_changed.connect(_on_view_changed)


func open(args: Dictionary) -> void:
	_args = args.duplicate(true)
	_closed = false
	_ensure()
	_fill()


func refresh(_view: Dictionary) -> void:
	if not _chrome or _closed:
		return
	_fill()


## Look, then close. Same state, same action. Does not mortgage on its own.
func autoplay_step() -> bool:
	if _closed:
		return false
	_request_close()
	return true


func dismiss() -> void:
	_request_close()


func _unhandled_input(event: InputEvent) -> void:
	_keys(event)


func _on_view_changed(_topics: PackedStringArray) -> void:
	call_deferred("_deferred_fill")


func _deferred_fill() -> void:
	if not is_inside_tree() or _closed or not _chrome:
		return
	_fill()


func _ensure() -> void:
	if _chrome:
		return
	_chrome = true
	var chrome: Dictionary = Ui.mount_drawer(self, &"estate")
	_body = chrome["body"]
	_body.add_child(_money_box())
	var head := Kit.heading_row(CardText.ui("c11.drawer.estates"), CardText.ui("c11.drawer.estates_note"))
	head.name = "head"
	_body.add_child(head)
	_list = VBoxContainer.new()
	_list.name = "list"
	_list.add_theme_constant_override("separation", 8)
	_body.add_child(_list)
	CardAnchors.register(&"a.estate.list", _list)
	_reason = Ui.line("", 15, false)
	_reason.name = "reason"
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason.clip_text = false
	_body.add_child(_reason)


## Money box (prototype .cashbox): coin x2, the amount in bold pale gold, the currency word.
func _money_box() -> PanelContainer:
	var sb := CardTheme.flat_style(&"wood_1", &"", 0, 4, 14.0, 8.0)
	sb.bg_color = CardTheme.with_alpha(&"gold_hi", 0.1)
	var box := Kit.box(sb)
	box.name = "money_box"
	var row := Kit.row(10)
	box.add_child(row)
	row.add_child(Kit.icon("icon.coin.head", 2))
	_money_n = Kit.label("0", 26, &"gold_pale", true)
	_money_n.name = "cash_n"
	row.add_child(_money_n)
	_money_unit = Kit.label("", 15, &"text_2")
	_money_unit.name = "cash_unit"
	_money_unit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_money_unit)
	return box


func _fill() -> void:
	if not _chrome:
		return
	# Build rows off-tree so each add_child does not re-sort the whole panel.
	var idx := _list.get_index()
	_body.remove_child(_list)
	Ui.clear(_list)
	var mortgage: Button = null
	for estate in _estates():
		if typeof(estate) != TYPE_DICTIONARY:
			continue
		var btn := _add_row(estate)
		if btn != null and mortgage == null:
			mortgage = btn
	_body.add_child(_list)
	_body.move_child(_list, idx)
	_show_copy.call_deferred()
	_fill_money()
	CardAnchors.register(&"a.estate.list", _list)
	if mortgage != null:
		CardAnchors.register(&"a.estate.mortgage", mortgage)
	Ui.chain_focus(self, _grab)
	_grab = false


func _estates() -> Array:
	if engine == null:
		return []
	var q := engine.query(&"estates", {})
	if q.has("estates") and typeof(q["estates"]) == TYPE_ARRAY:
		return q["estates"]
	var rows: Variant = engine.view().get("estates", [])
	return rows if typeof(rows) == TYPE_ARRAY else []


func _fill_money() -> void:
	if _money_n == null or engine == null:
		return
	var money: Variant = engine.view().get("money", {})
	var m: Dictionary = money if typeof(money) == TYPE_DICTIONARY else {}
	_money_n.text = str(int(m.get("amount", 0)))
	_money_unit.text = CardText.ui("c01.money.unit." + str(m.get("currency", "fabi")))


func _add_row(estate: Dictionary) -> Button:
	var id := str(estate.get("id", ""))
	var status := str(estate.get("status", ""))
	var row := VBoxContainer.new()
	row.name = "row_" + id.replace(".", "_")
	row.add_theme_constant_override("separation", 8)
	var line := Kit.row(10)
	row.add_child(line)
	var art := Ui.art_rect("illus." + id, 1, Vector2i(64, 48))
	art.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if status == "lost":
		art.modulate = CardTheme.with_alpha(&"text_3", 0.6)
	line.add_child(art)
	var col := _text_col(id, status)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_num_col(estate))
	_copy_line(col, id, status)
	line.add_child(col)
	var btn := _action_button(id, status)
	if btn != null:
		line.add_child(btn)
	row.add_child(Kit.divider())
	_list.add_child(row)
	return btn


func _text_col(id: String, status: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := Kit.row(8)
	col.add_child(top)
	var tkey := id + "#title"
	var title := Kit.label(CardText.card(id, "title"), 15, &"text_2" if CardText.is_draft(tkey) else &"hud_ink", true)
	title.name = "title"
	top.add_child(title)
	var skey := "c11.status." + status
	var tone := {"held": [&"wood_3", &"line", &"hud_ink"], "mortgaged": [&"seal_dark", &"seal", &"seal_rim"],
		"lost": [&"wood_1", &"line", &"text_3"]}
	var c: Array = tone.get(status, tone["held"])
	var sl := Kit.pill(CardText.ui(skey), c[0], c[1], c[2])
	sl.name = "status"
	top.add_child(sl)
	return col


## One line of copy: the estate's own line while held, what being pawned costs once it is out.
## Laid out after the open budget (the copy wraps): hidden here, shown by _show_copy before this frame draws.
func _copy_line(col: VBoxContainer, id: String, status: String) -> void:
	for field_name in PackedStringArray(["body", "mortgaged"]):
		var key := id + "#" + field_name
		var tone := &"text_2" if field_name == "body" else &"warn"
		var lab := Kit.label(CardText.card(id, field_name), 14, &"text_3" if CardText.is_draft(key) else tone)
		lab.name = field_name
		lab.clip_text = true
		lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lab.set_meta(&"c11_copy", field_name == ("body" if status == "held" else "mortgaged"))
		lab.visible = false
		col.add_child(lab)


func _show_copy() -> void:
	if not is_inside_tree() or _list == null:
		return
	for row in _list.get_children():
		for field_name in PackedStringArray(["body", "mortgaged"]):
			var copy := row.find_child(field_name, true, false) as CanvasItem
			if copy != null:
				copy.visible = bool(copy.get_meta(&"c11_copy", false))


## "pawn for n · monthly interest m": captions text_3, numbers bold (money pale gold).
func _num_col(estate: Dictionary) -> HBoxContainer:
	var col := Kit.row(4)
	col.name = "nums"
	col.add_child(Kit.label(CardText.ui("c11.money"), 14, &"text_3" if CardText.is_draft("c11.money") else &"text_2"))
	var money := Kit.label(str(int(estate.get("money", 0))), 14, &"gold_pale", true)
	money.name = "money_n"
	col.add_child(money)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(6, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	col.add_child(Kit.label(CardText.ui("c11.interest"), 14, &"text_3" if CardText.is_draft("c11.interest") else &"text_2"))
	var interest := Kit.label(str(int(estate.get("interest_money", 0))), 14, &"hud_ink", true)
	interest.name = "interest_n"
	col.add_child(interest)
	return col


func _action_button(id: String, status: String) -> Button:
	if status == "held":
		var b := Kit.small_button(CardText.ui("c11.btn.mortgage"))
		b.name = "mortgage"
		b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		b.custom_minimum_size = Vector2(72, 30)
		b.pressed.connect(_on_mortgage.bind(id))
		return b
	if status == "mortgaged":
		var b2 := Kit.small_button(CardText.ui("c11.btn.redeem"))
		b2.name = "redeem"
		b2.theme_type_variation = &"PrimaryButton"
		b2.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		b2.custom_minimum_size = Vector2(72, 30)
		b2.pressed.connect(_on_redeem.bind(id))
		return b2
	return null


func _on_mortgage(id: String) -> void:
	_send(&"estate.mortgage", id)


func _on_redeem(id: String) -> void:
	_send(&"estate.redeem", id)


func _send(cmd: StringName, id: String) -> void:
	if engine == null or _closed:
		return
	var r := engine.send(cmd, {"estate": id})
	if not bool(r.get("ok", false)):
		Ui.show_reason(_reason, r)
		return
	_reason.text = ""
	_fill()


func _request_close() -> void:
	if _closed:
		return
	_closed = true
	close_requested.emit({})


func _keys(event: InputEvent) -> void:
	var act := Ui.handle_key(self, event, true)
	if act == "":
		return
	if act == "close":
		_request_close()
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()
