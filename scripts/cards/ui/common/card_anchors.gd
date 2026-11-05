# 新手指引的锚点登记：每个界面部件把自己的锚点矩形登记上来，指引按锚点 id 找位置高亮。
# 只存 node 的 instance id（和可选的 rect_fn），不持有 Control 引用，不会泄漏、不会悬空；node 离开场景树时自动注销。
# 这是界面层唯一允许的可变静态表。主人 W0（Claude），冻结。合同：docs/cards/CARDS_INTERFACES.md §7.10.4、§7.10.5。
# 锚点 id 是封闭目录 CardIds.ANCHORS；每张牌的锚点写成 a.card@<uid>（数据里写 a.card@{uid}）。
class_name CardAnchors
extends RefCounted

static var _table: Dictionary = {}   # id → [{node: int, fn: Callable}]（后登记的在后面，盖住先登记的）


## rect_fn: func() -> Rect2（视口坐标），给只想高亮控件里一小块的部件用；不给就用整个控件
static func register(id: StringName, node: Control, rect_fn: Callable = Callable()) -> void:
	if node == null:
		return
	if not CardShip.is_ship() and not CardIds.is_known_anchor(str(id)):
		push_error("CardAnchors.register: '%s' is not in CardIds.ANCHORS" % id)
	unregister(id, node)
	if not _table.has(id):
		_table[id] = []
	(_table[id] as Array).append({"node": node.get_instance_id(), "fn": rect_fn})
	var cb := CardAnchors.unregister.bind(id, node)
	if not node.tree_exiting.is_connected(cb):
		node.tree_exiting.connect(cb, CONNECT_ONE_SHOT)


## 只注销这个 node 登记的那一条
static func unregister(id: StringName, node: Control) -> void:
	if not _table.has(id) or node == null:
		return
	var nid := node.get_instance_id()
	var rows: Array = _table[id]
	for i in range(rows.size() - 1, -1, -1):
		if int(rows[i]["node"]) == nid:
			rows.remove_at(i)
	if rows.is_empty():
		_table.erase(id)


## 视口坐标（1280×720 逻辑像素）；节点已释放、不在树里或 is_visible_in_tree() 为假 → Rect2()
static func rect(id: StringName) -> Rect2:
	var rows: Array = _table.get(id, [])
	for i in range(rows.size() - 1, -1, -1):
		var obj := instance_from_id(int(rows[i]["node"]))
		if obj == null or not is_instance_valid(obj) or not (obj is Control):
			continue
		var c := obj as Control
		if not c.is_inside_tree() or not c.is_visible_in_tree():
			continue
		var fn: Callable = rows[i]["fn"]
		if fn.is_valid():
			return fn.call()
		return c.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, c.size)
	return Rect2()


## rect(id) 有面积
static func has(id: StringName) -> bool:
	return rect(id).has_area()


## 排好序；测试、截图脚本用（只列现在还活着的）
static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for id in _table.keys():
		if has(id):
			out.append(str(id))
	out.sort()
	return out


## card_t.finish() 调；C01 换场景时调
static func clear() -> void:
	_table = {}
