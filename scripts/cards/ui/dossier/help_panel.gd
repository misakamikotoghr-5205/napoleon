# F1 帮助：操作页（c10.help.*，正文由 B 写）与规矩页。开着时 F1 或 Esc 关掉自己。
# 不吃 1-9。规矩栏与档案簿同一份子界面，解锁只看 firsts。主人 C10。
# 合同：docs/cards/CARDS_INTERFACES.md §3.3 C10、§7.8、§7.10.1。锚点 a.help.rules。
# 换皮（10-22）：深色叠层面板（modal_style，像素木框），标题毛笔金字，正文浅字；栏目按钮当前那栏金底深字（b49）。
# 遮罩由宿主的叠层给（_place_overlay），这里不再自己铺一层。
class_name CardHelpPanel
extends CardPanel

const RulesView = preload("res://scripts/cards/ui/dossier/rules_view.gd")
const Kit = preload("res://scripts/cards/ui/slots/drawer_kit.gd")
const BOOK_POS := Vector2(100, 50)
const BOOK_SIZE := Vector2(1080, 620)
const HELP_LINES: PackedStringArray = [
	"c10.help.title",
	"c10.help.keys.f1",
	"c10.help.keys.esc",
	"c10.help.keys.enter",
	"c10.help.keys.space",
	"c10.help.keys.tab",
	"c10.help.keys.num",
	"c10.help.day_flow",
]

var _args: Dictionary = {}
var _built: bool = false
var _did_auto: bool = false
var _tab: String = "controls"
var _book: Panel
var _body: Control
var _rules = null
var _tab_controls: Button
var _tab_rules: Button


func open(args: Dictionary) -> void:
	_args = args.duplicate(true)
	_ensure()
	_listen()
	_reload()


func refresh(_view: Dictionary) -> void:
	if not _built:
		return
	_reload()


func autoplay_step() -> bool:
	if _did_auto:
		return false
	_did_auto = true
	close_requested.emit({})
	return true


func _ensure() -> void:
	if _built:
		return
	_built = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)
	var back := Panel.new()
	back.name = "BookShadow"
	back.position = BOOK_POS
	back.size = BOOK_SIZE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_theme_stylebox_override("panel", CardTheme.modal_shadow_style())
	add_child(back)
	_book = Panel.new()
	_book.position = BOOK_POS
	_book.size = BOOK_SIZE
	_book.mouse_filter = Control.MOUSE_FILTER_STOP
	_book.add_theme_stylebox_override("panel", CardTheme.modal_style())
	add_child(_book)
	_tab_controls = _tab_button("c10.tab.controls", "controls", 36.0, 140.0)
	_tab_rules = _tab_button("c10.tab.rules", "rules", 184.0, 140.0)
	CardAnchors.register(&"a.help.rules", _tab_rules)
	var close := _tab_button("c10.btn.close", "close", BOOK_SIZE.x - 36.0 - 120.0, 120.0)
	close.pressed.connect(func() -> void: close_requested.emit({}))
	close.set_meta(&"c10_close", "1")
	var rule := ColorRect.new()
	rule.color = CardTheme.color(&"line")
	rule.position = Vector2(36, 76)
	rule.size = Vector2(BOOK_SIZE.x - 72.0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(rule)
	_body = Control.new()
	_body.name = "HelpBody"
	_body.position = Vector2(36, 92)
	_body.size = Vector2(BOOK_SIZE.x - 72.0, BOOK_SIZE.y - 124.0)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(_body)
	_rules = RulesView.new()
	_rules.name = "Rules"
	_rules.position = Vector2(36, 92)
	_rules.size = Vector2(BOOK_SIZE.x - 72.0, BOOK_SIZE.y - 124.0)
	_book.add_child(_rules)
	_rules.setup(engine)
	_rules.visible = false


func _listen() -> void:
	if bus == null:
		return
	if not bus.view_changed.is_connected(_on_view):
		bus.view_changed.connect(_on_view)


func _on_view(_topics: PackedStringArray) -> void:
	if _built:
		_reload()


func _reload() -> void:
	_fill_controls()
	_apply_tab()


func _fill_controls() -> void:
	_wipe(_body)
	var y := 8.0
	for key in HELP_LINES:
		var title := str(key) == "c10.help.title"
		var sz := 30 if title else 17
		var lab := Label.new()
		lab.text = CardText.ui(str(key))
		lab.position = Vector2(0, y)
		lab.size = Vector2(_body.size.x, 44 if title else 48)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.add_theme_font_size_override("font_size", sz)
		var draft := CardText.is_draft(str(key))
		var tone := &"gold_hi" if title else &"hud_ink"
		lab.add_theme_color_override("font_color", CardTheme.color(&"text_2" if draft else tone))
		lab.add_theme_font_override("font", CardTheme.font_title() if title else CardTheme.font_body())
		lab.set_meta(&"c10_help_key", str(key))
		_body.add_child(lab)
		y += 52.0 if title else 44.0


func _apply_tab() -> void:
	var controls := _tab == "controls"
	_body.visible = controls
	if _rules != null:
		if not controls:
			_rules.reload()
		_rules.visible = not controls
	_paint(_tab_controls, controls)
	_paint(_tab_rules, not controls)


func _step(delta: int) -> void:
	if _tab == "rules" and _rules != null:
		_rules.step(delta)
	elif delta > 0:
		_tab = "rules"
		_apply_tab()
	elif delta < 0:
		_tab = "controls"
		_apply_tab()


func _input(event: InputEvent) -> void:
	if not is_inside_tree() or not _topmost():
		return
	var wheel := _wheel(event)
	if wheel != 0:
		_take()
		_step(wheel)
		return
	var key := _key(event)
	if key == KEY_F1 or key == KEY_ESCAPE:
		_take()
		close_requested.emit({})
	elif key == KEY_LEFT or key == KEY_RIGHT:
		_take()
		_step(-1 if key == KEY_LEFT else 1)
	elif key == KEY_TAB:
		_take()
		_tab = "rules" if _tab == "controls" else "controls"
		_apply_tab()


func _topmost() -> bool:
	var parent := get_parent()
	if parent == null:
		return false
	var top: Node = null
	for c in parent.get_children():
		if c is CardPanel and (c as CanvasItem).is_visible_in_tree():
			top = c
	return top == self


func _tab_button(key: String, tab_id: String, x: float, w: float) -> Button:
	var b := Button.new()
	b.position = Vector2(x, 30)
	b.size = Vector2(w, 34)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.text = CardText.ui(key)
	Kit.paint_tab(b, false)
	b.set_meta(&"c10_tab", tab_id)
	if tab_id == "controls":
		b.pressed.connect(func() -> void:
			_tab = "controls"
			_apply_tab()
		)
	elif tab_id == "rules":
		b.pressed.connect(func() -> void:
			_tab = "rules"
			_apply_tab()
		)
	_book.add_child(b)
	return b


func _paint(b: Button, on: bool) -> void:
	Kit.paint_tab(b, on)


func _wipe(n: Node) -> void:
	var kids: Array = n.get_children()
	for c in kids:
		n.remove_child(c)
		(c as Node).queue_free()


func _take() -> void:
	if get_viewport() != null:
		get_viewport().set_input_as_handled()


func _key(event: InputEvent) -> Key:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		return (event as InputEventKey).keycode
	return KEY_NONE


func _wheel(event: InputEvent) -> int:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var b := (event as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_WHEEL_UP:
			return -1
		if b == MOUSE_BUTTON_WHEEL_DOWN:
			return 1
	return 0
