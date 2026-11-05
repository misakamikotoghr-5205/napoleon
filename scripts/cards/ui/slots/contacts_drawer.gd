# 人脉抽屉：你、人脉、留着的牌。只读，能拖进格子，不发指令。kind contacts。主人 C03。
# 合同：docs/cards/CARDS_INTERFACES.md §7.11.8。左抽屉框里那块 368x630（框内边距 16、标题行 44）。
# 换皮（10-22，照原型 31_drawer_contacts）：深底浅字；第一行永远是“你自己”，然后人脉，空位一句，
# 再是“留着的牌”小节（左边金线的批注条）。抽屉标题和“合上”是 C01 的框画的，这里不重复。
class_name CardContactsDrawer
extends CardPanel

const Kit = preload("res://scripts/cards/ui/slots/drawer_kit.gd")
const Row = preload("res://scripts/cards/ui/slots/drawer_row.gd")
const SIDE := "l"
const ROW_W := 352.0

var _scroll: ScrollContainer
var _list: VBoxContainer
var _closed: bool = false


func open(_args: Dictionary) -> void:
	_closed = false
	Kit.place(self, SIDE)
	_ensure()
	_refill(_view())


func refresh(view: Dictionary) -> void:
	if _closed:
		return
	_refill(view if typeof(view) == TYPE_DICTIONARY else {})


func autoplay_step() -> bool:
	if _closed:
		return false
	dismiss()
	return true


func dismiss() -> void:
	if _closed:
		return
	_closed = true
	close_requested.emit({})


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		dismiss()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()


func _ensure() -> void:
	if _list != null:
		return
	_scroll = Kit.scroll()
	_scroll.name = "Scroll"
	_scroll.position = Vector2(0, Kit.TOP_PAD)
	_scroll.size = size - Vector2(0, Kit.TOP_PAD)
	add_child(_scroll)
	_list = Kit.column(8)
	_list.name = "Rows"
	_list.custom_minimum_size = Vector2(ROW_W, 0)
	_scroll.add_child(_list)


func _refill(view: Dictionary) -> void:
	_ensure()
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var contacts := _rows(view.get("contacts", []))
	var kept := _rows(view.get("kept", []))
	var caps: Dictionary = view.get("caps", {}) if typeof(view.get("caps")) == TYPE_DICTIONARY else {}
	var cap := int(caps.get("contacts", 3))
	var intro := Kit.note(CardText.ui("c03.drawer.note", {"n": contacts.size(), "cap": cap}))
	intro.name = "Intro"
	intro.custom_minimum_size = Vector2(ROW_W, 0)
	_list.add_child(intro)
	var self_view: Dictionary = view.get("self", {}) if typeof(view.get("self")) == TYPE_DICTIONARY else {}
	if not self_view.is_empty():
		_list.add_child(_person_row("RowSelf", self_view, {"kind": "self"}, true))
	for row in contacts:
		var uid := str(row.get("uid", ""))
		_list.add_child(Kit.divider())
		_list.add_child(_person_row("Row_contact_%s" % uid, row, {"kind": "card", "uid": uid, "zone": "contacts"}, false))
	_list.add_child(Kit.divider())
	if contacts.size() < cap:
		var empty := Kit.label(CardText.ui("c03.drawer.empty"), 14, &"text_3", false, true)
		empty.name = "EmptyNote"
		empty.custom_minimum_size = Vector2(ROW_W, 0)
		_list.add_child(empty)
	var head := Kit.heading_row(CardText.ui("c03.drawer.kept"),
		CardText.ui("c03.drawer.kept_count", {"n": kept.size(), "cap": int(caps.get("kept", 5))}))
	head.name = "KeptHead"
	_list.add_child(_spacer(6))
	_list.add_child(head)
	if kept.is_empty():
		var none := Kit.label(CardText.ui("c03.drawer.kept_none"), 14, &"text_3", false, true)
		none.name = "KeptNone"
		_list.add_child(none)
	for row in kept:
		var uid := str(row.get("uid", ""))
		_list.add_child(_kept_row(row, {"kind": "card", "uid": uid, "zone": "kept"}))


## 人物行：48x64 头像（1px 边）、名字粗体（你自己带“你”字药丸）、人脉的一句介绍、四项本事、今天的状态。
func _person_row(node_name: String, row: Dictionary, payload: Dictionary, is_self: bool) -> Control:
	var line := _line(node_name, payload, null)
	var h := Kit.row(12)
	line.add_child(h)
	h.add_child(Kit.portrait(_portrait_of(row, is_self)))
	var col := Kit.column(3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	var top := Kit.row(8)
	col.add_child(top)
	var def_id := str(row.get("def", ""))
	var who := str(row.get("person", ""))
	var name_text := CardText.card(def_id, "title") if def_id != "" else CardText.person_name(who)
	var name := Kit.label(name_text, 15, &"hud_ink", true)
	name.name = "RowName"
	top.add_child(name)
	if is_self:
		var you := Kit.pill(CardText.ui("c03.drawer.you"))
		you.name = "YouPill"
		top.add_child(you)
	elif def_id != "":
		var sub := Kit.label(CardText.card(def_id, "body"), 14, &"text_2", false, true)
		sub.name = "RowBody"
		col.add_child(sub)
	col.add_child(_attrs(row))
	_add_state(col, row)
	return line


func _attrs(row: Dictionary) -> HBoxContainer:
	var attrs: Dictionary = row.get("attrs", {}) if typeof(row.get("attrs")) == TYPE_DICTIONARY else {}
	var box := Kit.row(4)
	box.name = "Attrs"
	for key in CardIds.ATTRS:
		var cap := Kit.label(CardText.ui("c03.attr." + str(key)), 14, &"text_2")
		cap.name = "AttrName_%s" % str(key)
		box.add_child(cap)
		var num := Kit.label(str(int(attrs.get(key, 0))), 14, &"hud_ink", true)
		num.name = "Attr_%s" % str(key)
		num.custom_minimum_size = Vector2(14, 0)
		box.add_child(num)
	return box


## 留着的牌：左边金线的批注条；牌名粗体，下面一句“怎么用”，会过期的带“还剩 n 天”药丸。
func _kept_row(row: Dictionary, payload: Dictionary) -> Control:
	var line := _line("Row_kept_%s" % str(row.get("uid", "")), payload, CardTheme.row_note_style())
	var col := Kit.column(2)
	line.add_child(col)
	var def_id := str(row.get("def", ""))
	var top := Kit.row(8)
	col.add_child(top)
	var title := Kit.label(CardText.card(def_id, "title"), 15, &"hud_ink", true)
	title.name = "RowTitle"
	top.add_child(title)
	var days := int(row.get("expires_in", -1))
	if days >= 0:
		var urgent := days <= 1
		var state := Kit.pill(CardText.t("c03.state.days", {"n": days}),
			&"seal" if urgent else &"wood_3", &"seal_dark" if urgent else &"line", &"btn_warn_ink" if urgent else &"hud_ink")
		state.name = "StateDays"
		top.add_child(state)
	var use := Kit.label(CardText.card(def_id, "use"), 14, &"text_2", false, true)
	use.name = "RowUse"
	col.add_child(use)
	return line


func _add_state(col: Control, row: Dictionary) -> void:
	if bool(row.get("used_today", false)):
		var used := Kit.label(CardText.ui("c03.state.used"), 14, &"warn")
		used.name = "StateUsed"
		col.add_child(used)
	var away := int(row.get("away_days", 0))
	if away > 0:
		var state := Kit.label(CardText.t("c03.state.away", {"n": away}), 14, &"bad")
		state.name = "StateAway"
		col.add_child(state)


func _line(node_name: String, payload: Dictionary, style: StyleBox) -> Control:
	var line := Row.new()
	line.name = node_name
	line.payload = payload
	line.custom_minimum_size = Vector2(ROW_W, 0)
	line.add_theme_stylebox_override("panel", style if style != null else StyleBoxEmpty.new())
	return line


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## 头像：牌视图的 art；“你自己”的视图不带 art，按牌 id self.<人> 找 portrait.<人>（同英雄栏）。
func _portrait_of(row: Dictionary, is_self: bool) -> String:
	var art := str(row.get("art", ""))
	if art != "":
		return art
	var who := str(row.get("person", ""))
	if who == "" and is_self:
		var def_id := str(row.get("def", ""))
		who = def_id.substr(5) if def_id.begins_with("self.") else ""
	return "portrait." + who if who != "" else ""


func _view() -> Dictionary:
	if engine == null:
		return {}
	var raw = engine.view()
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


func _rows(raw) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for r in raw:
		if typeof(r) == TYPE_DICTIONARY:
			out.append(r)
	return out
