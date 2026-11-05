# 条子抽屉：左抽屉里嵌条子板。点一行先收回抽屉，再开 demand 那一出。
# 主人 C05。合同：docs/cards/CARDS_INTERFACES.md §7.8、§7.11.8。kind demands。
# 换皮（10-22，原型 32_drawer_notes）：摆在左抽屉框里那块（368x630），深底；抽屉框已经有标题和“合上”，
# 这里只有一句说明、条子纸片一张张往下排，没有条子时一句“还没有条子”。
class_name CardDemandsDrawer
extends CardPanel

const BOARD_SCENE := preload("res://scenes/cards/demand/DemandBoard.tscn")
const Kit = preload("res://scripts/cards/ui/slots/drawer_kit.gd")
const SIDE := "l"

var _board: CardDemandBoard
var _note: Label
var _empty: Label
var _built: bool = false


func open(_args: Dictionary) -> void:
	_ensure()
	if engine != null and _board != null:
		refresh(engine.view())


func refresh(view: Dictionary) -> void:
	if _board == null:
		return
	_board.refresh(view)
	var rows = view.get("demands", [])
	_empty.visible = typeof(rows) != TYPE_ARRAY or (rows as Array).is_empty()


## 看一眼就关。不替玩家点条子。
func autoplay_step() -> bool:
	dismiss()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		dismiss()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()


func _ensure() -> void:
	if _built:
		return
	_built = true
	Kit.place(self, SIDE)
	var col := Kit.column(10)
	col.name = "Body"
	col.position = Vector2(0, Kit.TOP_PAD)
	col.size = size - Vector2(0, Kit.TOP_PAD)
	add_child(col)
	_note = Kit.note(CardText.ui("c05.drawer.note"))
	_note.name = "Intro"
	col.add_child(_note)
	_empty = Kit.label(CardText.ui("c05.drawer.empty"), 14, &"text_3")
	_empty.name = "EmptyNote"
	_empty.visible = false
	col.add_child(_empty)
	_board = BOARD_SCENE.instantiate() as CardDemandBoard
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.size = Vector2(size.x, size.y - 80.0)
	col.add_child(_board)
	_board.show_title(false)
	_board.demand_pressed.connect(_on_row)


func _on_row(uid: String) -> void:
	var host := _find_host()
	close_requested.emit({})
	if host != null:
		host.open_panel(&"demand", {"uid": uid})


func _find_host() -> CardModalHost:
	var n: Node = self
	while n != null:
		if n is CardModalHost:
			return n as CardModalHost
		n = n.get_parent()
	return null
