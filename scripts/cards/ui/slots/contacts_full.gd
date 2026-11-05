# 人脉满了：列出现有人脉和新来的那位，选一个让出来（contact.release）。
# 关掉 / Esc = 新来的不留（contact.release {uid: new_uid}）。叠层，合同 1.3 不改画法。
# 主人 C03。合同：docs/cards/CARDS_INTERFACES.md §3.3 C03、§7.4、§7.8、§7.10.5。
# 新来的人先认 args.new_uid，没有就看 view.pending 里 type == contact 的。
class_name CardContactsFull
extends CardPanel

const Ui = preload("res://scripts/cards/ui/slots/slot_ui.gd")
const CARD_SCENE := preload("res://scenes/cards/card/CardWidget.tscn")

var _list: HBoxContainer
var _title: Label
var _view: Dictionary = {}
var _args: Dictionary = {}
var _uids: Array[String] = []
var _new_uid: String = ""
var _picked: bool = false
var _closed: bool = false


func open(args: Dictionary) -> void:
	_args = args.duplicate(true)
	_picked = false
	_closed = false
	_uids = []
	_view = {}
	if engine != null:
		var view = engine.view()
		if typeof(view) == TYPE_DICTIONARY:
			_view = view
	_new_uid = str(_args.get("new_uid", ""))
	if _new_uid == "":
		_new_uid = _pending_uid("contact")
	_ensure()
	_refill()


func refresh(view: Dictionary) -> void:
	if _picked:
		return
	if typeof(view) == TYPE_DICTIONARY:
		_view = view
	_refill()


func autoplay_step() -> bool:
	if _closed or engine == null or _uids.is_empty():
		return false
	_release(_uids[0])
	return true


func can_close() -> bool:
	return true


## 算了：还没选就让出新来的那位；已经选过只关。
func dismiss() -> void:
	if _picked or _closed:
		_request_close()
		return
	if _new_uid != "" and engine != null:
		_release(_new_uid)
		return
	_request_close()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		dismiss()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()


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
	_title = Ui.label(CardText.ui("c03.contacts_full.title"), 32, CardText.is_draft("c03.contacts_full.title"))
	_title.name = "Title"
	Ui.pin(_title, Vector2(844, 40))
	col.add_child(_title)
	_list = HBoxContainer.new()
	_list.name = "ReleaseList"
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_theme_constant_override("separation", 8)
	Ui.pin(_list, Vector2(844, 140))
	col.add_child(_list)
	CardAnchors.register(&"a.slots.release", _list)


func _refill() -> void:
	if _list == null:
		return
	Ui.clear(_list)
	_uids.clear()
	var rows = _view.get("contacts", [])
	if typeof(rows) == TYPE_ARRAY:
		for row in rows:
			if typeof(row) != TYPE_DICTIONARY:
				continue
			var uid := str(row.get("uid", ""))
			_uids.append(uid)
			_list.add_child(_mini(row, "Rel_" + uid, uid))
	if _new_uid != "":
		var cap := Ui.label(CardText.ui("c03.contacts_full.new"), 14, CardText.is_draft("c03.contacts_full.new"))
		cap.name = "NewCaption"
		Ui.pin(cap, Vector2(96, 100))
		_list.add_child(cap)
		_list.add_child(_mini(_card_of(_new_uid, "contact"), "NewCard", ""))


func _mini(cv: Dictionary, node_name: String, release_uid: String) -> CardWidget:
	var widget := CARD_SCENE.instantiate() as CardWidget
	widget.name = node_name
	widget.bus = bus
	widget.set_size_mode(&"mini")
	widget.set_card(cv)
	if release_uid != "":
		widget.pressed.connect(_on_pressed.bind(release_uid))
	else:
		widget.set_highlight(true)
	return widget


func _on_pressed(_widget_uid: String, uid: String) -> void:
	_release(uid)


func _release(uid: String) -> void:
	if _picked or engine == null or uid == "":
		return
	_picked = true
	engine.send(&"contact.release", {"uid": uid})
	_request_close()


func _request_close() -> void:
	if _closed:
		return
	_closed = true
	close_requested.emit({})


func _pending_uid(type_name: String) -> String:
	var rows = _view.get("pending", [])
	if typeof(rows) != TYPE_ARRAY:
		return ""
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY and str(row.get("type", "")) == type_name:
			return str(row.get("uid", ""))
	return ""


func _card_of(uid: String, type_name: String) -> Dictionary:
	for key in ["contacts", "hand", "pending", "kept"]:
		var rows = _view.get(key, [])
		if typeof(rows) != TYPE_ARRAY:
			continue
		for row in rows:
			if typeof(row) == TYPE_DICTIONARY and str(row.get("uid", "")) == uid:
				return row
	return {"uid": uid, "def": "", "type": type_name, "zone": "pending", "art": "", "actions": [], "expires_in": -1}
