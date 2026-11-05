# 剧情 VN 的立绘台：最多三个人站在左 / 中 / 右，底边贴着屏幕下沿，高约 690（逻辑像素）。
# 人数一变就重新排开（一人居中，两人左右，三人左中右；按 vn_cast.json 写的 left / center / right 排先后）；
# 说话的人亮、略大、站到最前，其他人压暗、略缩；上场从外侧滑入淡入，下场滑出淡出；换表情用真图的表情贴图
# （没有就是剪影上的表情徽记）。立绘来自 HdPlaceholder.make_chara（有真图用真图）。没有 class_name。
extends Control

const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const HdPlaceholder = preload("res://scripts/cards/ui/hd/hd_placeholder.gd")
const Data = preload("res://scripts/cards/ui/vn/vn_data.gd")

const CHARA_H := 690.0
const CHARA_W := 460.0   # 1200:1800
const STAGE_H := 720.0
const ORDER := {"left": 0, "center": 1, "right": 2}
## 人数 -> 每个人的中心 x
const SLOTS := {1: [640.0], 2: [410.0, 870.0], 3: [300.0, 640.0, 980.0]}
const MOVE_S := 0.38
const FOCUS_S := 0.22
const DIM_SCALE := 0.965
## 占位剪影的肩线（1200×1800 画布里的 y）：名字牌挂在这条线上
const CHIP_LINE := 615.0

## 快动画（测试、快进）：没有补间，直接到位
var fast := false
## Per-scene costume ids (C16); each stage keeps its own map, never global state.
var art_overrides: Dictionary = {}
## 名字牌显示着（菜单、记录开着时收起）
var _chips_on := true

## [{id, holder, node, order, seq, spoke, expr, leaving}]
var _actors: Array = []
var _seq := 0
var _clock := 0
var _focus := ""
var _narration := true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## 台上的人（从左到右）
func actor_ids() -> Array:
	var out: Array = []
	for a in _sorted():
		out.append(str(a["id"]))
	return out


func has_actor(id: String) -> bool:
	return not _find(id).is_empty()


func focused() -> String:
	return _focus


func expr_of(id: String) -> String:
	var a := _find(id)
	return str(a.get("expr", "")) if not a.is_empty() else ""


## 立绘节点（测试、截图用）
func actor_node(id: String) -> Control:
	var a := _find(id)
	return a.get("node") if not a.is_empty() else null


## 上场：at 是 left / center / right（排先后用）；已经在台上就只换位置偏好和表情
func enter(id: String, at: String = "", expr: String = "") -> void:
	if id == "":
		return
	var a := _find(id)
	if not a.is_empty():
		if at in ORDER:
			a["order"] = int(ORDER[at])
		if expr != "":
			set_expr(id, expr)
		_layout(true)
		return
	var live := _sorted()
	while live.size() >= Data.max_on_stage():
		var out := _least_recent(live)
		if out.is_empty():
			break
		leave(str(out["id"]))
		live = _sorted()
	_seq += 1
	var face := expr if expr in Data.EXPRS else "normal"
	var node := HdPlaceholder.make_chara(Data.art_id(id, art_overrides), CardText.person_name(id), face)
	if HdPlaceholder.is_placeholder(node):
		node.set("show_name", false)
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	var holder := Control.new()
	holder.name = "Actor_" + id
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = Vector2(CHARA_W, CHARA_H)
	holder.pivot_offset = Vector2(CHARA_W * 0.5, CHARA_H)
	holder.add_child(node)
	holder.add_child(_name_chip(CardText.person_name(id)))
	add_child(holder)
	var order := int(ORDER.get(at, 2 if id != Data.protagonist() else 0))
	var row := {"id": id, "holder": holder, "node": node, "order": order, "seq": _seq, "spoke": 0, "expr": face,
		"leaving": false}
	_actors.append(row)
	# 从外侧滑进来：左半边的人从左边来，右半边的从右边来
	var x := _target_x(row)
	holder.position = Vector2(x - CHARA_W * 0.5 + (-90.0 if x < 640.0 else 90.0), STAGE_H - CHARA_H)
	holder.modulate = _tint(row, 0.0)
	_layout(true)


## 占位剪影都长一个样：肩线上挂一枚名字牌，台上几个人分得清（底下剪影自带的名字压在文本框后面看不见）。
## 有真立绘时不挂。每个人都挂在同一条肩线上（占位剪影的肩在 1200×1800 画布的 y≈CHIP_LINE），按立绘框缩放，
## 名字牌竖直居中在这条线上，不压脸和下巴
func _name_chip(text: String) -> Control:
	var chip := PanelContainer.new()
	chip.name = "NameChip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.anti_aliasing = true
	sb.bg_color = HdTheme.alpha("hd_ink", 0.78)
	sb.border_color = HdTheme.alpha("hd_gold", 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(11)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 2
	sb.content_margin_bottom = 3
	chip.add_theme_stylebox_override(&"panel", sb)
	var l := HdTheme.make_label(text, 15, "title", "hd_text")
	chip.add_child(l)
	chip.reset_size()
	var ms := chip.get_combined_minimum_size()
	chip.position = Vector2((CHARA_W - ms.x) * 0.5, roundf(CHARA_H * CHIP_LINE / 1800.0 - ms.y * 0.5))
	chip.visible = _chips_on
	return chip


## 名字牌全部显示 / 收起（抉择菜单、对话记录盖着台子时收起，台上的人淡下去也不留一串名字）
func set_chips_visible(on: bool) -> void:
	_chips_on = on
	for a in _actors:
		var holder: Control = a["holder"]
		if not is_instance_valid(holder):
			continue
		var chip := holder.get_node_or_null("NameChip") as CanvasItem
		if chip != null:
			chip.visible = on


## 下场（滑出淡出后释放）
func leave(id: String) -> void:
	var a := _find(id)
	if a.is_empty():
		return
	a["leaving"] = true
	_actors.erase(a)
	_kill(a, "tw_pos")
	_kill(a, "tw_tint")
	var holder: Control = a["holder"]
	if _focus == id:
		_focus = ""
	if fast or not is_inside_tree():
		holder.queue_free()
	else:
		var dx := -70.0 if holder.position.x + CHARA_W * 0.5 < 640.0 else 70.0
		var tw := holder.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(holder, "position:x", holder.position.x + dx, 0.3)
		tw.tween_property(holder, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(holder.queue_free)
	_layout(true)


func clear() -> void:
	for a in _actors:
		var holder: Control = a["holder"]
		if is_instance_valid(holder):
			holder.queue_free()
	_actors = []
	_focus = ""


func set_expr(id: String, expr: String) -> void:
	var a := _find(id)
	if a.is_empty() or not (expr in Data.EXPRS):
		return
	a["expr"] = expr
	HdPlaceholder.set_chara_expr(a["node"], Data.art_id(id, art_overrides), expr)


## 谁在说话：id 上台的人亮起来、站到最前；id 为空 = 旁白（大家一样亮，略暗一点）
func focus(id: String) -> void:
	_clock += 1
	_focus = id if has_actor(id) else ""
	_narration = _focus == ""
	var a := _find(_focus)
	if not a.is_empty():
		a["spoke"] = _clock
		move_child(a["holder"], -1)
	_apply_tints(true)


## 一下子到位（快进、重开时把台子摆成最后的样子）
func settle() -> void:
	var was := fast
	fast = true
	_layout(false)
	_apply_tints(false)
	fast = was


func _layout(animate: bool) -> void:
	var live := _sorted()
	for a in live:
		var holder: Control = a["holder"]
		var to := Vector2(_target_x(a) - CHARA_W * 0.5, STAGE_H - CHARA_H)
		_kill(a, "tw_pos")
		if fast or not animate or not is_inside_tree():
			holder.position = to
			continue
		var tw := holder.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(holder, "position", to, MOVE_S)
		a["tw_pos"] = tw
	_apply_tints(animate)


func _apply_tints(animate: bool) -> void:
	for a in _actors:
		var holder: Control = a["holder"]
		var lit := _narration or str(a["id"]) == _focus
		var s := 1.0 if lit else DIM_SCALE
		_kill(a, "tw_tint")
		if fast or not animate or not is_inside_tree():
			holder.scale = Vector2(s, s)
			holder.modulate = _tint(a, 1.0)
			continue
		var tw := holder.create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(holder, "scale", Vector2(s, s), FOCUS_S)
		tw.tween_property(holder, "modulate", _tint(a, 1.0), FOCUS_S)
		a["tw_tint"] = tw


func _kill(a: Dictionary, key: String) -> void:
	var tw = a.get(key)
	if tw is Tween and (tw as Tween).is_valid():
		(tw as Tween).kill()
	a.erase(key)


func _tint(a: Dictionary, alpha: float) -> Color:
	var c: Color
	if _narration:
		c = HdTheme.color("hd_vn_mid")
	elif str(a["id"]) == _focus:
		c = HdTheme.color("hd_white")
	else:
		c = HdTheme.color("hd_vn_dim")
	c.a = alpha
	return c


func _target_x(row: Dictionary) -> float:
	var live := _sorted()
	var xs: Array = SLOTS.get(clampi(live.size(), 1, 3), SLOTS[1])
	var i := live.find(row)
	if i < 0:
		# 还没进表（刚造出来）：按它的先后猜一个
		var probe := live.duplicate()
		probe.append(row)
		probe.sort_custom(_before)
		xs = SLOTS.get(clampi(probe.size(), 1, 3), SLOTS[1])
		i = probe.find(row)
	return float(xs[clampi(i, 0, xs.size() - 1)])


func _sorted() -> Array:
	var live := _actors.duplicate()
	live.sort_custom(_before)
	return live


func _before(x: Dictionary, y: Dictionary) -> bool:
	if int(x["order"]) != int(y["order"]):
		return int(x["order"]) < int(y["order"])
	return int(x["seq"]) < int(y["seq"])


## 台上满了要让一个人下去：最久没说话的、不是正在说话的那个
func _least_recent(live: Array) -> Dictionary:
	var pick := {}
	for a in live:
		if str(a["id"]) == _focus:
			continue
		if pick.is_empty() or int(a["spoke"]) < int(pick["spoke"]) \
				or (int(a["spoke"]) == int(pick["spoke"]) and int(a["seq"]) < int(pick["seq"])):
			pick = a
	return pick


func _find(id: String) -> Dictionary:
	for a in _actors:
		if str(a["id"]) == id:
			return a
	return {}
