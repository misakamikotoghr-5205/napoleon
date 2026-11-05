# 一个格子：拖放目标，显示已放的东西和每样给几枚铜钱，拿出来。C05、C06、C11 复用。
# 主人 C03。合同：docs/cards/CARDS_INTERFACES.md §3.3 C03、§7.4、§7.8、§7.11.7。
# 放下时自己发 ui_event slot_drop {uid, slot, kind}。slot_view 没有 coins 键时不显示铜钱数。
# 1.3：柜台上 160×120（多于 4 格时由宿主缩到 slot_rect）。空格子点一下请宿主弹选择器。
# 换皮（10-22，照原型 58/60）：深底、2px 金色虚线框、圆角 6；放了东西变实线、底亮一档；拖着能放的东西经过时
# 边变 gold_pale、底 slot_over、放大 1.04；一拖起能放进来的东西，空格子外圈发光。上面是格子名（金字），
# 中间放了的东西（小头像/图标 + 名字 + 铜钱数），下面是“放…”/“取出”小按钮；钱格是“−5 / ＋5”（b37）。
class_name CardSlotWidget
extends Control

signal place_requested(slot_id: String, source: Dictionary)
signal remove_requested(slot_id: String, index: int)
signal empty_pressed(slot_id: String)
signal money_step(slot_id: String, sign: int)

const Ui = preload("res://scripts/cards/ui/slots/slot_ui.gd")
const Kit = preload("res://scripts/cards/ui/slots/drawer_kit.gd")
const PAD := Vector2(6, 5)
const DASH := 6.0

## 发 ui_event 用（宿主注入；没注入时用 autoload CardBus）
var bus: CardEventBus = null

var _card_uid: String = ""
var _slot: Dictionary = {}
var _col: VBoxContainer
var _wants: HBoxContainer
var _rows: VBoxContainer
var _total_box: HBoxContainer
var _total: Label
var _foot: HBoxContainer
var _put: Button
var _money: HBoxContainer
var _minus: Button
var _plus: Button
var _empty: Label
var _show_coins: bool = false
var _money_unit: int = 0
var _over: bool = false
var _glow: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(160, 120)
	size = custom_minimum_size
	clip_contents = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_col = VBoxContainer.new()
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_theme_constant_override("separation", 2)
	add_child(_col)
	_wants = HBoxContainer.new()
	_wants.name = "Head"
	_wants.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wants.alignment = BoxContainer.ALIGNMENT_CENTER
	_wants.add_theme_constant_override("separation", 6)
	_col.add_child(_wants)
	_rows = VBoxContainer.new()
	_rows.name = "Placed"
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.alignment = BoxContainer.ALIGNMENT_CENTER
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 2)
	_col.add_child(_rows)
	_empty = Kit.label(CardText.ui("c03.slot.empty"), 14, &"text_3")
	_empty.name = "EmptyHint"
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.visible = false
	_rows.add_child(_empty)
	_total_box = HBoxContainer.new()
	_total_box.name = "TotalBox"
	_total_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_total_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_total_box.add_theme_constant_override("separation", 3)
	_total_box.visible = false
	_col.add_child(_total_box)
	_total_box.add_child(_coin_icon())
	_total = Kit.label("0", 14, &"gold_hi", true)
	_total.name = "SlotTotal"
	_total.visible = false
	_total_box.add_child(_total)
	_foot = HBoxContainer.new()
	_foot.name = "Foot"
	_foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foot.alignment = BoxContainer.ALIGNMENT_CENTER
	_foot.add_theme_constant_override("separation", 6)
	_col.add_child(_foot)
	_put = _small(CardText.ui("c03.slot.put"))
	_put.name = "PutBtn"
	_put.pressed.connect(_on_put)
	_foot.add_child(_put)
	_money = HBoxContainer.new()
	_money.name = "MoneyPad"
	_money.visible = false
	_money.mouse_filter = Control.MOUSE_FILTER_PASS
	_money.alignment = BoxContainer.ALIGNMENT_CENTER
	_money.add_theme_constant_override("separation", 6)
	_foot.add_child(_money)
	_minus = _small(CardText.ui("c03.money.minus"))
	_minus.name = "MoneyMinus"
	_minus.custom_minimum_size = Vector2(48, 26)
	_minus.pressed.connect(_step_money.bind(-1))
	_money.add_child(_minus)
	_plus = _small(CardText.ui("c03.money.plus"))
	_plus.name = "MoneyPlus"
	_plus.custom_minimum_size = Vector2(48, 26)
	_plus.pressed.connect(_step_money.bind(1))
	_money.add_child(_plus)
	_layout()


func fit(rect: Rect2) -> void:
	layout_mode = 0
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = rect.position
	custom_minimum_size = rect.size
	size = rect.size
	offset_left = rect.position.x
	offset_top = rect.position.y
	offset_right = rect.position.x + rect.size.x
	offset_bottom = rect.position.y + rect.size.y
	_layout()


func set_slot(card_uid: String, slot_view: Dictionary) -> void:
	_card_uid = card_uid
	_slot = slot_view.duplicate(true) if typeof(slot_view) == TYPE_DICTIONARY else {}
	_show_coins = _slot.has("coins")
	_refill()


func set_money_unit(unit: int) -> void:
	_money_unit = unit
	_money.visible = unit > 0
	_sync_foot()
	_refresh_money()


func shows_coins() -> bool:
	return _show_coins


func money_pad() -> Control:
	return _money


func money_unit() -> int:
	return _money_unit


func accepts_kind(kind: String) -> bool:
	return _accepts().has(kind)


## 选择器走和拖拽同一条放下路径（发 place_requested 和 slot_drop）。
func offer(source: Dictionary) -> void:
	if source.is_empty():
		return
	_accept(source)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var ok := _can_take(data)
	_set_over(ok)
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_over(false)
	var src := _map(data)
	if src.is_empty():
		return
	_accept(src)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _placed().is_empty():
		return
	empty_pressed.emit(str(_slot.get("id", "")))
	accept_event()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			_layout()
		NOTIFICATION_MOUSE_EXIT:
			_set_over(false)
		NOTIFICATION_DRAG_BEGIN:
			var vp := get_viewport()
			var data: Variant = vp.gui_get_drag_data() if vp != null else null
			_glow = _placed().is_empty() and _can_take(data)
			queue_redraw()
		NOTIFICATION_DRAG_END:
			_glow = false
			_set_over(false)
			queue_redraw()


## 底、框、发光都在这里画（StyleBoxFlat 画不了虚线）。
func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var filled := not _placed().is_empty()
	if _glow and not _over:
		var halo := StyleBoxFlat.new()
		halo.bg_color = CardTheme.with_alpha(&"gold_hi", 0.0)
		halo.set_corner_radius_all(8)
		halo.shadow_color = CardTheme.with_alpha(&"gold_hi", 0.55)
		halo.shadow_size = 10
		draw_style_box(halo, r)
	var sb := StyleBoxFlat.new()
	sb.bg_color = CardTheme.color(&"slot_over" if _over else (&"slot_full" if filled else &"slot_bg"))
	sb.set_corner_radius_all(6)
	sb.shadow_color = CardTheme.with_alpha(&"scene_void", 0.5)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	var edge := CardTheme.color(&"gold_pale") if _over else CardTheme.color(&"slot_edge")
	if filled or _over:
		edge.a = 1.0
		sb.border_color = edge
		sb.set_border_width_all(2)
		draw_style_box(sb, r)
		return
	draw_style_box(sb, r)
	_dashed_rect(r.grow(-1.0), edge, 2.0)


func _dashed_rect(r: Rect2, c: Color, w: float) -> void:
	var rad := 5.0
	var a := r.position
	var b := r.end
	draw_dashed_line(Vector2(a.x + rad, a.y), Vector2(b.x - rad, a.y), c, w, DASH, true)
	draw_dashed_line(Vector2(a.x + rad, b.y), Vector2(b.x - rad, b.y), c, w, DASH, true)
	draw_dashed_line(Vector2(a.x, a.y + rad), Vector2(a.x, b.y - rad), c, w, DASH, true)
	draw_dashed_line(Vector2(b.x, a.y + rad), Vector2(b.x, b.y - rad), c, w, DASH, true)
	draw_arc(Vector2(a.x + rad, a.y + rad), rad, PI, PI * 1.5, 4, c, w)
	draw_arc(Vector2(b.x - rad, a.y + rad), rad, PI * 1.5, TAU, 4, c, w)
	draw_arc(Vector2(b.x - rad, b.y - rad), rad, 0.0, PI * 0.5, 4, c, w)
	draw_arc(Vector2(a.x + rad, b.y - rad), rad, PI * 0.5, PI, 4, c, w)


func _layout() -> void:
	if _col == null:
		return
	_col.position = PAD
	_col.size = Vector2(maxf(40.0, size.x - PAD.x * 2.0), maxf(40.0, size.y - PAD.y * 2.0))
	pivot_offset = size * 0.5
	queue_redraw()


func _set_over(on: bool) -> void:
	if _over == on:
		return
	_over = on
	scale = Vector2(1.04, 1.04) if on else Vector2.ONE
	queue_redraw()


func _can_take(data: Variant) -> bool:
	var src := _map(data)
	if src.is_empty():
		return false
	var accepts: Array = _accepts()
	if accepts.is_empty():
		return true
	return accepts.has(str(src.get("kind", "")))


func _accept(source: Dictionary) -> void:
	var slot_id := str(_slot.get("id", ""))
	place_requested.emit(slot_id, source)
	_emit_drop(str(source.get("kind", "")))


func _emit_drop(kind: String) -> void:
	var target := bus
	if target == null and is_inside_tree():
		target = get_node_or_null("/root/CardBus") as CardEventBus
	if target != null:
		target.ui_event.emit(&"slot_drop", {"uid": _card_uid, "slot": str(_slot.get("id", "")), "kind": kind})


func _refill() -> void:
	Ui.clear(_wants)
	for child in _rows.get_children():
		if child != _empty:
			_rows.remove_child(child)
			child.free()
	for child in _foot.get_children():
		if str(child.name).begins_with("Remove"):
			_foot.remove_child(child)
			child.free()
	for key in _head_keys():
		var lab := Kit.label(CardText.ui(key), 14, &"gold_hi")
		lab.name = "Wants"
		lab.clip_text = false
		_wants.add_child(lab)
	if bool(_slot.get("required", false)):
		var must := Kit.pill(CardText.ui("c03.slot.required"), &"seal_dark", &"seal", &"seal_rim")
		must.name = "Required"
		_wants.add_child(must)
	var placed: Array = _placed()
	for i in placed.size():
		if typeof(placed[i]) == TYPE_DICTIONARY:
			_rows.add_child(_placed_row(placed[i], i))
	_total_box.visible = _show_coins and placed.size() > 1
	_total.visible = _show_coins
	_total.text = str(int(_slot.get("coins", 0))) if _show_coins else ""
	_sync_foot()
	_refresh_money()
	queue_redraw()


## 钱格：中间“空着”、底下 −/＋；别的格子：空着时底下一个“放东西…”，放了东西换成“取出”。
func _sync_foot() -> void:
	var empty := _placed().is_empty()
	_empty.visible = empty and _money_unit > 0
	_put.visible = empty and _money_unit <= 0
	for child in _foot.get_children():
		if str(child.name).begins_with("Remove"):
			(child as Control).visible = _money_unit <= 0


## 格子名：wants（官面、证件…）+ 要哪项本事；都没有时按收什么（人、钱、货、消息）说一句。
func _head_keys() -> Array:
	var keys: Array = []
	for tag in _wants_of():
		keys.append("c03.wants." + str(tag))
	var attr := str(_slot.get("attr", ""))
	if _wants_of().is_empty():
		var acc := _accepts()
		if acc.has("self") or acc.has("contact"):
			keys.append("c03.wants.person")
		elif acc.has("money"):
			keys.append("c03.wants.money")
		elif acc.has("item"):
			keys.append("c03.wants.goods")
		elif acc.has("news"):
			keys.append("c03.wants.news")
		elif acc.has("kept"):
			keys.append("c03.wants.papers")
	if attr != "":
		keys.append("c03.attr." + attr)
	return keys


func _placed_row(row: Dictionary, index: int) -> Control:
	var col := VBoxContainer.new()
	col.name = "PlacedRow%d" % index
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 4)
	col.add_child(line)
	line.add_child(_thumb(row))
	var name_text := str(row.get("label", ""))
	if name_text != "":
		var who := Kit.label(name_text, 14, &"hud_ink")
		who.name = "PlacedName"
		who.clip_text = true
		who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		who.custom_minimum_size = Vector2(minf(72.0, maxf(24.0, size.x - 96.0)), 0)
		line.add_child(who)
	if _show_coins:
		line.add_child(_coin_icon())
		var coins := Kit.label(str(int(row.get("coins", 0))), 14, &"gold_hi", true)
		coins.name = "PlacedCoins"
		line.add_child(coins)
	if int(row.get("heads", 0)) != 0:
		var heads := Kit.label(str(int(row.get("heads", 0))), 14, &"money_up", true)
		heads.name = "PlacedHeads"
		line.add_child(heads)
	if bool(row.get("auto_pass", false)):
		var mark := Kit.label(CardText.ui("c03.coins.auto_pass"), 14, &"money_up")
		mark.name = "AutoPass"
		mark.clip_text = true
		mark.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		mark.custom_minimum_size = Vector2(minf(96.0, size.x - 12.0), 0)
		col.add_child(mark)
	var btn := _small(CardText.ui("c03.btn.remove"))
	btn.name = "Remove%d" % index
	btn.pressed.connect(_emit_remove.bind(index))
	_foot.add_child(btn)
	_foot.move_child(btn, 0)
	return col


## 放进来的东西的小图：人取头像上半截 28x28；留着的牌是红色“留”字圆章；钱、货、消息用 16x16 小图标。
func _thumb(row: Dictionary) -> Control:
	var kind := str(row.get("kind", ""))
	var art := str(row.get("art", ""))
	if kind == "kept":
		var seal := Kit.brush(CardText.ui("c03.slot.kept_mark"), 14, &"seal_rim")
		seal.name = "KeptSeal"
		seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		seal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		seal.custom_minimum_size = Vector2(24, 24)
		seal.add_theme_stylebox_override("normal", CardTheme.flat_style(&"seal", &"seal_dark", 1, 12, 0.0, 0.0))
		seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return seal
	var icon_id := ""
	match kind:
		"money":
			icon_id = "icon.demand.money"
		"item":
			icon_id = "icon.demand.goods"
		"news":
			icon_id = "icon.demand.info"
	if icon_id != "":
		return Kit.icon(icon_id, 1)
	if art == "":
		var blank := Control.new()
		blank.custom_minimum_size = Vector2(4, 24)
		blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return blank
	var face := Kit.face(art, Vector2i(28, 28), 1)
	face.name = "Thumb"
	face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return face


func _coin_icon() -> TextureRect:
	var r := Kit.icon("icon.coin.head", 1)
	r.name = "CoinIcon"
	return r


func _small(text: String) -> Button:
	var b := Kit.small_button(text)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(0, 26)
	b.add_theme_constant_override("h_separation", 2)
	return b


## 钱格的 −/＋：没放钱时“少一份”灰掉（b37）。
func _refresh_money() -> void:
	if _minus == null:
		return
	var has_money := false
	for row in _placed():
		if typeof(row) == TYPE_DICTIONARY and str(row.get("kind", "")) == "money":
			has_money = true
	_minus.disabled = not has_money
	# The pad only shows on money slots (unit > 0). Unused, as on the wheel's incense table, it carries no
	# number at all (QA 10-25: C06 keeps every digit off the wheel panel, hidden nodes included).
	var unit := _money_unit
	_minus.text = CardText.ui("c03.money.minus", {"n": unit}) if unit > 0 else ""
	_plus.text = CardText.ui("c03.money.plus", {"n": unit}) if unit > 0 else ""


func _on_put() -> void:
	empty_pressed.emit(str(_slot.get("id", "")))


func _emit_remove(index: int) -> void:
	remove_requested.emit(str(_slot.get("id", "")), index)


func _step_money(sign: int) -> void:
	if sign < 0 and _minus != null and _minus.disabled:
		return
	money_step.emit(str(_slot.get("id", "")), sign)


func _map(data: Variant) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var raw: Dictionary = data
	var kind := str(raw.get("kind", ""))
	if kind == "money":
		return {"kind": "money", "amount": int(raw.get("amount", 0))}
	if kind == "item":
		return {"kind": "item", "item": str(raw.get("item", ""))}
	if kind == "self":
		return {"kind": "self"}
	if kind == "kept" or kind == "contact" or kind == "news":
		return {"kind": kind, "uid": str(raw.get("uid", ""))}
	if kind != "card":
		return {}
	return _map_card(raw)


func _map_card(raw: Dictionary) -> Dictionary:
	var zone := str(raw.get("zone", ""))
	var uid := str(raw.get("uid", ""))
	if zone == "kept":
		return {"kind": "kept", "uid": uid}
	if zone == "contacts":
		return {"kind": "contact", "uid": uid}
	if zone == "self":
		return {"kind": "self"}
	return {"kind": "news", "uid": uid}


func _accepts() -> Array:
	var raw = _slot.get("accepts", [])
	return raw if typeof(raw) == TYPE_ARRAY else []


func _placed() -> Array:
	var raw = _slot.get("placed", [])
	return raw if typeof(raw) == TYPE_ARRAY else []


func _wants_of() -> Array:
	var raw = _slot.get("wants", [])
	return raw if typeof(raw) == TYPE_ARRAY else []
