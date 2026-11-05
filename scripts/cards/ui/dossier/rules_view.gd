# 规矩栏。档案簿和 F1 帮助各放一份。解锁只看 firsts 与 unlock_first 的交集，按 order 排。
# 解锁不看玩家把指引关掉没有，也不看指引进度。没解锁的页不出现。主人 C10。不写 class_name。
# 合同：docs/cards/CARDS_INTERFACES.md §3.3 C10、§4.7.21、§7.4、§7.10.10。
# 换皮（10-22，原型 37_drawer_rules）：深底；当前这一条是左边金线的批注条（谁教的 · 小金字、毛笔标题、正文），
# 下面（宽的时候在左边）是全部规矩的目录，当前那条金线高亮（b49：不再是灰底金字）。窄（抽屉 368 宽）上下排，宽（帮助）左右排。
extends Control

const WIDE := 600.0
const LIST_W := 260.0

var _engine: CardEngineApi
var _pages: Array = []
var _index: int = 0
var _box: BoxContainer
var _detail: PanelContainer
var _scroll: ScrollContainer
var _list: VBoxContainer
var _title: Label
var _body: Label
var _teacher: Label
var _buttons: Array = []


func setup(p_engine: CardEngineApi) -> void:
	_engine = p_engine
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not resized.is_connected(_layout):
		resized.connect(_layout)
	_build()
	reload()


func rule_ids() -> Array:
	var out: Array = []
	for p in _pages:
		out.append(str((p as Dictionary).get("id", "")))
	return out


func current_id() -> String:
	if _pages.is_empty():
		return ""
	return str((_pages[_index] as Dictionary).get("id", ""))


func step(delta: int) -> void:
	if _pages.is_empty():
		return
	_select(_wrap(_index + delta, _pages.size()))


func _wrap(i: int, n: int) -> int:
	var m := i
	while m < 0:
		m += n
	while m >= n:
		m -= n
	return m


func reload() -> void:
	_pages = _collect()
	if _index >= _pages.size():
		_index = 0
	_fill_list()
	_show_current()
	_layout()


func _build() -> void:
	if _box != null:
		return
	_box = BoxContainer.new()
	_box.name = "Stack"
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 12)
	add_child(_box)
	_detail = PanelContainer.new()
	_detail.name = "Detail"
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var note := CardTheme.row_note_style(&"gold_hi", 3)
	note.bg_color = CardTheme.with_alpha(&"paper", 0.08)
	note.content_margin_top = 10.0
	note.content_margin_bottom = 12.0
	_detail.add_theme_stylebox_override("panel", note)
	_box.add_child(_detail)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	_detail.add_child(col)
	_teacher = _label(14, &"gold_deep", CardTheme.font_body())
	_teacher.name = "RuleTeacher"
	col.add_child(_teacher)
	_title = _label(24, &"gold_hi", CardTheme.font_title())
	_title.name = "RuleTitle"
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(_title)
	_body = _label(15, &"hud_ink", CardTheme.font_body())
	_body.name = "RuleBody"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_constant_override("line_spacing", 4)
	col.add_child(_body)
	_scroll = ScrollContainer.new()
	_scroll.name = "ListScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list)


func _collect() -> Array:
	if _engine == null:
		return []
	var data: Dictionary = _engine.query(&"guide_data", {})
	var raw: Array = data.get("pages", []) if typeof(data.get("pages")) == TYPE_ARRAY else []
	var firsts := _firsts()
	var out: Array = []
	for p in raw:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		if _unlocked(p, firsts):
			out.append(p)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ao := int(a.get("order", 0))
		var bo := int(b.get("order", 0))
		if ao != bo:
			return ao < bo
		return str(a.get("id", "")) < str(b.get("id", ""))
	)
	return out


func _firsts() -> Dictionary:
	var q: Dictionary = _engine.query(&"firsts", {})
	var raw = q.get("firsts", {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


func _unlocked(page: Dictionary, firsts: Dictionary) -> bool:
	var keys: Array = page.get("unlock_first", []) if typeof(page.get("unlock_first")) == TYPE_ARRAY else []
	for m in keys:
		var name := str(m)
		if firsts.has(name):
			return true
		for k in firsts.keys():
			if str(k) == name:
				return true
	return false


func _fill_list() -> void:
	_wipe(_list)
	_buttons.clear()
	for i in range(_pages.size()):
		var id := str((_pages[i] as Dictionary).get("id", ""))
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 36)
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = CardText.card(id, "title")
		b.add_theme_font_override("font", CardTheme.font_body())
		b.add_theme_font_size_override("font_size", 15)
		b.set_meta(&"c10_rule", id)
		b.pressed.connect(_select.bind(i))
		_list.add_child(b)
		_buttons.append(b)
	_paint_list()


func _select(i: int) -> void:
	if _pages.is_empty():
		return
	_index = clampi(i, 0, _pages.size() - 1)
	_show_current()
	_paint_list()


func _show_current() -> void:
	if _title == null:
		return
	if _pages.is_empty():
		_title.text = ""
		_body.text = ""
		_teacher.text = ""
		_detail.visible = false
		return
	_detail.visible = true
	var page: Dictionary = _pages[_index]
	var id := str(page.get("id", ""))
	_title.text = CardText.card(id, "title")
	_title.add_theme_color_override("font_color", CardTheme.color(&"text_2" if CardText.is_draft(id + "#title") else &"gold_hi"))
	_body.text = CardText.card(id, "body")
	_body.add_theme_color_override("font_color", CardTheme.color(&"text_2" if CardText.is_draft(id + "#body") else &"hud_ink"))
	_teacher.text = _teacher_line(str(page.get("teacher", "")))
	_teacher.visible = _teacher.text != ""
	if _box != null:
		_fit_box.call_deferred()


func _teacher_line(teacher: String) -> String:
	if teacher == "":
		return ""
	if teacher == "obj.notice":
		return CardText.ui("c10.teacher.notice")
	if teacher == "obj.almanac":
		return CardText.ui("c10.teacher.almanac")
	if teacher == "obj.brother_ledger":
		return CardText.ui("c10.teacher.brother_ledger")
	return CardText.person_name(teacher)


## 目录：当前那条是金线批注条、金字；其余透明底浅字，悬停一层淡金。
func _paint_list() -> void:
	var on_box := CardTheme.row_note_style(&"gold_hi", 3)
	on_box.bg_color = CardTheme.with_alpha(&"gold_hi", 0.12)
	var off_box := CardTheme.row_note_style(&"line", 1)
	off_box.bg_color = CardTheme.with_alpha(&"paper", 0.03)
	var hover_box := CardTheme.row_note_style(&"gold_deep", 3)
	hover_box.bg_color = CardTheme.color(&"reply_hover")
	for i in range(_buttons.size()):
		var b := _buttons[i] as Button
		var on := i == _index
		for s in [&"normal", &"focus", &"disabled"]:
			b.add_theme_stylebox_override(s, on_box if on else off_box)
		for s in [&"hover", &"pressed", &"hover_pressed"]:
			b.add_theme_stylebox_override(s, on_box if on else hover_box)
		var ink := CardTheme.color(&"gold_pale" if on else &"hud_ink")
		for c in [&"font_color", &"font_focus_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
			b.add_theme_color_override(c, ink if (on or c == &"font_color" or c == &"font_focus_color") else CardTheme.color(&"gold_pale"))
		b.add_theme_font_override("font", CardTheme.font_body_bold() if on else CardTheme.font_body())


func _layout() -> void:
	if _box == null:
		return
	_box.position = Vector2.ZERO
	_box.size = size
	var wide := size.x >= WIDE
	# 自动换行的正文先给定宽度，最小高度才按这个宽度算（不然头一回排版按 0 宽算成一长条，把整栏撑出抽屉）。
	_body.custom_minimum_size = Vector2(maxf(80.0, (size.x - LIST_W - 12.0 if wide else size.x) - 30.0), 0)
	_fit_box.call_deferred()
	_box.vertical = not wide
	if wide:
		_box.move_child(_scroll, 0)
		_scroll.custom_minimum_size = Vector2(LIST_W, 0)
		_scroll.size_flags_horizontal = Control.SIZE_FILL
		_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_detail.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	else:
		_box.move_child(_detail, 0)
		_scroll.custom_minimum_size = Vector2(0, 120)
		_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_detail.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _fit_box() -> void:
	if _box != null and is_instance_valid(_box):
		_box.size = size


func _label(sz: int, tone: StringName, font: Font) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", CardTheme.color(tone))
	l.add_theme_font_override("font", font)
	return l


func _wipe(n: Node) -> void:
	if n == null:
		return
	var kids: Array = n.get_children()
	for c in kids:
		n.remove_child(c)
		(c as Node).queue_free()
