# 留牌满了：五张留着的 + 新来的那张，选一张扔掉（card.discard）。
# 关面板（按钮、Esc、宿主直接释放）= 扔掉新来的那张，每次打开恰好发一次。
# 主人 C03。合同：docs/cards/CARDS_INTERFACES.md §3.3 C03、§7.4.2、§7.8、§7.10.5。
class_name CardKeptFull
extends CardPanel

const Ui = preload("res://scripts/cards/ui/slots/slot_ui.gd")
const CARD_SCENE := preload("res://scenes/cards/card/CardWidget.tscn")

var _list: HBoxContainer
var _title: Label
var _close_btn: Button
var _view: Dictionary = {}
var _args: Dictionary = {}
var _new_uid: String = ""
var _done: bool = false
var _closed: bool = false


func open(args: Dictionary) -> void:
	_args = args.duplicate(true)
	_done = false
	_closed = false
	_view = {}
	if engine != null:
		var view = engine.view()
		if typeof(view) == TYPE_DICTIONARY:
			_view = view
	_new_uid = str(_args.get("new_uid", ""))
	if _new_uid == "":
		_new_uid = _pending_uid()
	_ensure()
	_refill()


func refresh(view: Dictionary) -> void:
	if _done:
		return
	if typeof(view) == TYPE_DICTIONARY:
		_view = view
	_refill()


func autoplay_step() -> bool:
	if _closed or engine == null:
		return false
	_close_as_drop()
	return true


func can_close() -> bool:
	return true


## 算了：扔掉新来的那张（和关掉、Esc 同一条路）。
func dismiss() -> void:
	_close_as_drop()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		dismiss()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()


func _exit_tree() -> void:
	if _done:
		return
	_done = true
	var eng := engine
	var uid := _new_uid
	if eng != null:
		eng.call_deferred("send", &"card.discard", {"uid": uid})


func _ensure() -> void:
	if _list != null:
		return
	var box := Ui.mount(self, Vector2(920, 420))
	box.name = "PanelBox"
	var col := VBoxContainer.new()
	col.position = Vector2(38, 34)
	col.size = Vector2(844, 300)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 8)
	box.add_child(col)
	_title = Ui.label(CardText.ui("c03.kept_full.title"), 32, CardText.is_draft("c03.kept_full.title"))
	_title.name = "Title"
	Ui.pin(_title, Vector2(844, 40))
	col.add_child(_title)
	_list = HBoxContainer.new()
	_list.name = "DiscardList"
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_theme_constant_override("separation", 8)
	Ui.pin(_list, Vector2(844, 140))
	col.add_child(_list)
	CardAnchors.register(&"a.slots.discard", _list)
	_close_btn = Ui.button(CardText.ui("c03.btn.close"))
	_close_btn.name = "CloseBtn"
	_close_btn.pressed.connect(_close_as_drop)
	# 关上摆在面板右下角（不随牌那一排往下挤，也不压在牌上）。
	_close_btn.position = Vector2(box.size.x - 38.0 - 120.0, box.size.y - 34.0 - 36.0)
	_close_btn.size = Vector2(120, 36)
	box.add_child(_close_btn)


func _refill() -> void:
	if _list == null:
		return
	Ui.clear(_list)
	var rows = _view.get("kept", [])
	if typeof(rows) == TYPE_ARRAY:
		for row in rows:
			if typeof(row) != TYPE_DICTIONARY:
				continue
			var uid := str(row.get("uid", ""))
			_list.add_child(_mini(row, "Disc_" + uid, uid, false))
	if _new_uid != "":
		var cap := Ui.label(CardText.ui("c03.kept_full.new"), 14, CardText.is_draft("c03.kept_full.new"))
		cap.name = "NewCaption"
		Ui.pin(cap, Vector2(96, 100))
		_list.add_child(cap)
		_list.add_child(_mini(_card_of(_new_uid), "DiscNew", _new_uid, true))


func _mini(cv: Dictionary, node_name: String, uid: String, incoming: bool) -> CardWidget:
	var widget := CARD_SCENE.instantiate() as CardWidget
	widget.name = node_name
	widget.bus = bus
	widget.set_size_mode(&"mini")
	widget.set_card(cv)
	widget.pressed.connect(_on_pressed.bind(uid))
	if incoming:
		widget.set_highlight(true)
	return widget


func _on_pressed(_widget_uid: String, uid: String) -> void:
	_pick(uid)


func _pick(uid: String) -> void:
	if _done or engine == null:
		return
	_done = true
	engine.send(&"card.discard", {"uid": uid})
	_request_close()


func _close_as_drop() -> void:
	if not _done and engine != null:
		_done = true
		engine.send(&"card.discard", {"uid": _new_uid})
	_request_close()


func _request_close() -> void:
	if _closed:
		return
	_closed = true
	close_requested.emit({})


func _pending_uid() -> String:
	var rows = _view.get("pending", [])
	if typeof(rows) != TYPE_ARRAY:
		return ""
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if str(row.get("type", "")) == "kept" or str(row.get("status", "")) == "overflow":
			return str(row.get("uid", ""))
	return ""


func _card_of(uid: String) -> Dictionary:
	for key in ["kept", "hand", "pending"]:
		var rows = _view.get(key, [])
		if typeof(rows) != TYPE_ARRAY:
			continue
		for row in rows:
			if typeof(row) == TYPE_DICTIONARY and str(row.get("uid", "")) == uid:
				return row
	return {"uid": uid, "def": "", "type": "kept", "zone": "pending", "art": "", "actions": [], "expires_in": -1}
