# 暂停：继续、存档说明、设置、帮助、回标题、退出。不挡指引以外的玩法；autoplay 走继续。
# 主人 C16（换皮这一轮归 C01 外框那一路改）。合同：docs/cards/CARDS_INTERFACES.md §3.3 C16、§7.8、§7.10.5（锚点 a.pause.help）。
# close_requested 的 next / to_title / quit 由 C01 的宿主解释。
# 换皮（10-22）：深色叠层面板（主题默认的 modal 样子，遮罩由叠层宿主画），毛笔金标题，“回到柜台”是金色主按钮。
# 键盘（b05）：上下在按钮里绕圈（焦点邻居只指自己人），焦点变了 _index 跟着变，回车按的是有焦点的那颗。
# 离开 / 回到标题（b50）：先问一句（早上以后的进度会丢），点“确定”才发 quit / to_title。
class_name CardPause
extends CardPanel

const KIND := &"pause"
const BOX_W := 440.0
const BUTTON_W := 300.0
const BUTTON_H := 44.0

var _buttons: Array[Button] = []
var _index: int = 0
var _closed: bool = false
var _box: PanelContainer = null
var _confirming: String = ""


func open(_args: Dictionary) -> void:
	_closed = false
	_index = 0
	_confirming = ""
	# The overlay host pins panels to OVERLAY_MAX; the pause covers the whole screen and centres its box.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = -_parent_origin()
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for c in get_children():
		c.free()
	_buttons = []
	_build()


func refresh(_view: Dictionary) -> void:
	pass


func autoplay_step() -> bool:
	if _closed:
		return false
	_closed = true
	close_requested.emit({})
	return true


func _build() -> void:
	_box = PanelContainer.new()
	_box.name = "Box"
	_box.theme_type_variation = &"ModalPanel"
	add_child(_box)
	_fill_menu()


func _column() -> VBoxContainer:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_buttons = []
	var col := VBoxContainer.new()
	col.name = "Column"
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	_box.add_child(col)
	var head := Label.new()
	head.name = "Heading"
	head.theme_type_variation = &"ModalTitle"
	head.text = CardText.ui("c16.pause.heading")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	return col


func _fill_menu() -> void:
	_confirming = ""
	var col := _column()
	_add_button(col, "resume", {}, &"PrimaryButton")
	var note := Label.new()
	note.name = "SaveNote"
	note.theme_type_variation = &"NoteLabel"
	note.text = CardText.ui("c16.pause.save_note")
	note.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.custom_minimum_size = Vector2(BUTTON_W, 0)
	col.add_child(note)
	_add_button(col, "settings", {"next": {"kind": "settings", "args": {}}})
	_add_button(col, "help", {"next": {"kind": "help", "args": {}}})
	_add_button(col, "title", {"to_title": true})
	_add_button(col, "quit", {"quit": true})
	for btn in _buttons:
		if btn.name == "help":
			CardAnchors.register(&"a.pause.help", btn)
	_finish()


## b50: leaving drops whatever was done since this morning's save, so ask once.
func _fill_confirm(what: String) -> void:
	_confirming = what
	var col := _column()
	var note := Label.new()
	note.name = "Confirm"
	note.text = CardText.ui("c16.pause.confirm_" + what)
	note.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.custom_minimum_size = Vector2(BUTTON_W, 0)
	col.add_child(note)
	var result := {"quit": true} if what == "quit" else {"to_title": true}
	var yes := _make_button("confirm_yes", &"WarnButton")
	yes.pressed.connect(_emit.bind(result))
	col.add_child(yes)
	var no := _make_button("confirm_no", &"")
	no.pressed.connect(_back_to_menu)
	col.add_child(no)
	_finish()
	_select(1)


func _finish() -> void:
	for i in _buttons.size():
		_buttons[i].focus_entered.connect(_on_focus.bind(i))
	_wire_neighbours()
	_box.reset_size()
	_box.custom_minimum_size = Vector2(BOX_W, 0)
	_box.reset_size()
	_box.position = ((Vector2(1280, 720) - _box.size) * 0.5).floor()
	if not _buttons.is_empty():
		if is_inside_tree():
			_select(0)
		else:
			tree_entered.connect(_select.bind(0), CONNECT_ONE_SHOT)


func _parent_origin() -> Vector2:
	var parent := get_parent() as Control
	return parent.get_global_rect().position if parent != null else Vector2.ZERO


func _make_button(key: String, variation: StringName) -> Button:
	var btn := Button.new()
	btn.name = key
	btn.text = CardText.ui("c16.pause." + key)
	btn.custom_minimum_size = Vector2(BUTTON_W, BUTTON_H)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_ALL
	if variation != &"":
		btn.theme_type_variation = variation
	_buttons.append(btn)
	return btn


func _add_button(col: Control, key: String, result: Dictionary, variation: StringName = &"") -> void:
	var btn := _make_button(key, variation)
	var payload := result.duplicate(true)
	if key == "quit" or key == "title":
		btn.pressed.connect(_ask.bind(key))
	else:
		btn.pressed.connect(_emit.bind(payload))
	col.add_child(btn)


func _ask(what: String) -> void:
	if _closed:
		return
	_fill_confirm.call_deferred(what)


func _back_to_menu() -> void:
	if _closed:
		return
	_fill_menu.call_deferred()


func _emit(payload: Dictionary) -> void:
	if _closed:
		return
	_closed = true
	close_requested.emit(payload.duplicate(true))


func _wire_neighbours() -> void:
	var n := _buttons.size()
	for i in n:
		var me := _buttons[i]
		var prev := _buttons[_wrap(i - 1, n)]
		var nxt := _buttons[_wrap(i + 1, n)]
		me.focus_neighbor_top = me.get_path_to(prev)
		me.focus_neighbor_left = me.get_path_to(prev)
		me.focus_previous = me.get_path_to(prev)
		me.focus_neighbor_bottom = me.get_path_to(nxt)
		me.focus_neighbor_right = me.get_path_to(nxt)
		me.focus_next = me.get_path_to(nxt)


func _unhandled_input(event: InputEvent) -> void:
	if _closed or not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	if (event as InputEventKey).echo:
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_UP or key == KEY_W:
		_move(-1)
	elif key == KEY_DOWN or key == KEY_S:
		_move(1)
	elif key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SPACE:
		_activate()
	elif key == KEY_ESCAPE and _confirming != "":
		_back_to_menu()
	else:
		return
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()


func _move(dir: int) -> void:
	var n := _buttons.size()
	if n == 0:
		return
	_select(_wrap(_index + dir, n))


func _wrap(i: int, n: int) -> int:
	if n <= 0:
		return 0
	var x := i
	while x < 0:
		x += n
	while x >= n:
		x -= n
	return x


func _select(i: int) -> void:
	if i < 0 or i >= _buttons.size():
		return
	_index = i
	if _buttons[i].is_inside_tree():
		_buttons[i].grab_focus()


func _on_focus(i: int) -> void:
	_index = i


## The focused button if it is one of ours (keyboard focus and highlight are the same thing), else _index.
func _activate() -> void:
	var vp := get_viewport()
	var focus := vp.gui_get_focus_owner() if vp != null else null
	var i := _buttons.find(focus as Button) if focus is Button else -1
	if i < 0:
		i = _index
	if i < 0 or i >= _buttons.size():
		return
	_buttons[i].pressed.emit()
