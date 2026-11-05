# 炉石式手牌扇：白天排手上的牌再接留着的牌，夜里排夜牌和“睡了”。
# 主人 C02。合同 §7.11.6。实现 CardHandApi。悬停抬起，选中才放大。
# 锚点：a.hand、a.hand.gold、a.hand.kept、a.hand.preview。
# ui_event：hand_selected、hand_played、card_zoomed、card_drag_started。不发 first_time。
# 换皮（10-22，照网页原型，换皮 SPEC §8）：
#   层次只靠树里的先后，不用 z_index（b02：手牌的 z 会画到叠层上面；整个扇子 z 都是 0）。
#   悬停的牌挪到所有牌后面（画在最上、点击也先到它，b13），抬起时它的点击区一直延到原来的位置，鼠标往下移不会换牌；
#   抬起、放下用 0.18 秒补间，日结说话时整排 0.4 秒滑下淡出；快动画开关打开时直接到位。
#   选中：深色托盘（L 形，右下让出账簿热点，b42）里放大的牌 + 右边一列按钮（主题变体：打出是 PrimaryButton，
#   b11），按钮字照原型按牌换；托盘 0.15 秒淡入。
#   拖拽：影子是同尺寸的牌（转 -4 度），原位那张变淡；场景外框亮起、正中偏上一行“放到这里：打出这张牌”。
#   只有被拖的那张在拖完时出牌（NOTIFICATION_DRAG_END 每个节点都会收到）。
class_name CardHandFan
extends CardHandApi

const CARD := Vector2(144, 200)
const CENTER_X := 690.0
const REST_TOP := 544.0
const HOVER_TOP := 380.0
const AWAY_TOP := 760.0
const LOW_DY := 56.0
const PIVOT := Vector2(72, 280)
## 补间时长（秒）：悬停抬起、下沉、预览淡入、整排滑走。合同：单段不超过 0.6。
const HOVER_SEC := 0.18
const PREVIEW_SEC := 0.15
const AWAY_SEC := 0.4
## 预览按钮高、间距；托盘比放大牌和按钮列各宽出 12。
const BTN_H := 40.0
const BTN_GAP := 10.0
const TRAY_PAD := 12.0
## 拖拽时场景外框（CardStage 收牌的范围 y 30..560）。
const DROP_RECT := Rect2(2, 32, 1276, 526)

var bus: CardEventBus = null
## 快动画：不播补间，直接到位（冻结读取是 CardSettings.fast_anim()；测试用这个布尔）。
var fast_anim: bool = false

var _cards: Array = []
var _slots: Array[Control] = []
var _selected: int = -1
var _hover: int = -1
var _low: bool = false
var _away: bool = false
var _phase: String = ""
var _fast_setting: bool = false
var _drag_index: int = -1
var _drop_over: bool = false
var _band: Control
var _kept_box: Control
var _tray: Tray
var _preview: CardWidget
var _note: Label
var _drop_ring: Panel
var _drop_glow: Panel
var _drop_hint: Label
var _buttons: Control
var _play: Button
var _keep: Button
var _back: Button


class Slot:
	extends Control
	var fan: CardHandFan
	var index: int = -1
	## 抬起时还认“原位露出来的那一条”（父节点坐标里没抬起时的摆法 rest_xform，条宽 rest_strip）：
	## 抬起会摆正、往右挪一点，鼠标原来指着这张牌的左边缘时不会掉到左边那张上（试玩：20 张牌指大命运点成了邻牌）。
	var lifted: bool = false
	var rest_xform := Transform2D()
	var rest_strip := Rect2()

	func _has_point(point: Vector2) -> bool:
		if Rect2(Vector2.ZERO, size).has_point(point):
			return true
		if not lifted or rest_strip.size == Vector2.ZERO:
			return false
		return rest_strip.has_point(rest_xform.affine_inverse() * (get_transform() * point))

	func _get_drag_data(at_position: Vector2) -> Variant:
		if fan == null:
			return null
		return fan._slot_drag(index, at_position)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END and fan != null:
			fan._slot_drag_end(index)


## 选中预览的托盘（原型 .pvwrap）：放大牌那一块 + 按钮那一列连成一个 L 形，右下缺一角让出账簿。
class Tray:
	extends Control
	var card_rect := Rect2()
	var side_rect := Rect2()
	var radius := 10.0

	func setup(card_r: Rect2, side_r: Rect2) -> void:
		var all := card_r.merge(side_r)
		position = all.position
		size = all.size
		card_rect = Rect2(card_r.position - all.position, card_r.size)
		side_rect = Rect2(side_r.position - all.position, side_r.size)
		queue_redraw()

	## 屏幕上的点在不在托盘里（测试 b42 用）。
	func covers(at: Vector2) -> bool:
		var p := at - position
		return card_rect.has_point(p) or side_rect.has_point(p)

	## 托盘只在 L 形里吃鼠标（右下缺角让给账簿热点，b42）。
	func _has_point(point: Vector2) -> bool:
		return card_rect.has_point(point) or side_rect.has_point(point)

	func _draw() -> void:
		var shadow := StyleBoxFlat.new()
		shadow.bg_color = Color.TRANSPARENT
		shadow.shadow_color = CardTheme.with_alpha(&"scene_void", 0.7)
		shadow.shadow_size = 28
		shadow.shadow_offset = Vector2(0, 14)
		shadow.set_corner_radius_all(int(radius))
		draw_style_box(shadow, card_rect)
		draw_style_box(shadow, side_rect)
		var pts := _outline()
		draw_colored_polygon(pts, CardTheme.with_alpha(&"scene_void", 0.92))
		var ring := pts.duplicate()
		ring.append(pts[0])
		draw_polyline(ring, CardTheme.color(&"umber"), 2.0, true)

	func _outline() -> PackedVector2Array:
		var l := card_rect.position.x
		var t := minf(card_rect.position.y, side_rect.position.y)
		var r := side_rect.end.x
		var notch_y := side_rect.end.y
		var notch_x := card_rect.end.x
		var b := card_rect.end.y
		var corners: Array[Vector2] = [Vector2(l + 1, t + 1), Vector2(r - 1, t + 1), Vector2(r - 1, notch_y - 1),
			Vector2(notch_x - 1, notch_y - 1), Vector2(notch_x - 1, b - 1), Vector2(l + 1, b - 1)]
		var out := PackedVector2Array()
		var n := corners.size()
		for i in n:
			var a: Vector2 = corners[(i + n - 1) % n]
			var p: Vector2 = corners[i]
			var c: Vector2 = corners[(i + 1) % n]
			var rr := minf(radius, minf(a.distance_to(p), p.distance_to(c)) * 0.5)
			var p0 := p + (a - p).normalized() * rr
			var p1 := p + (c - p).normalized() * rr
			for k in 7:
				var s := float(k) / 6.0
				out.append(p0.lerp(p, s).lerp(p.lerp(p1, s), s))
		return out


func _ready() -> void:
	_build()


func refresh(view: Dictionary) -> void:
	_build()
	_fast_setting = CardSettings.fast_anim()
	var keep_uid := ""
	var keep_def := ""
	if _selected >= 0 and _selected < _cards.size():
		keep_uid = str(_cards[_selected].get("uid", ""))
		keep_def = str(_cards[_selected].get("def", ""))
	_clear_cards()
	_phase = str(view.get("phase", ""))
	if _phase == "day":
		for card in _as_array(view.get("hand", [])):
			if typeof(card) == TYPE_DICTIONARY:
				_cards.append((card as Dictionary).duplicate(true))
		for card in _as_array(view.get("kept", [])):
			if typeof(card) == TYPE_DICTIONARY:
				_cards.append((card as Dictionary).duplicate(true))
	elif _phase == "night":
		for offer in _as_array(view.get("night_offers", [])):
			_cards.append(_offer_card(offer))
		_cards.append({"uid": "", "def": ""})
	_selected = -1
	_hover = -1
	for i in _cards.size():
		_add_slot(i)
		if keep_uid == str(_cards[i].get("uid", "")) and keep_def == str(_cards[i].get("def", "")):
			if keep_uid != "" or keep_def != "":
				_selected = i
	_restack()
	_layout_cards(0.0)
	_sync_marks()
	_sync_preview()
	_sync_note()


func set_low(on: bool) -> void:
	_low = on
	_build()
	_layout_cards(HOVER_SEC)
	_sync_band()


func set_away(on: bool) -> void:
	_away = on
	_build()
	_layout_cards(AWAY_SEC)
	_sync_band()
	_sync_preview()
	_sync_note()


func select_index(i: int) -> void:
	if i < 0 or i >= _cards.size():
		return
	_selected = i
	_layout_cards(0.0)
	_sync_preview()
	var uid := str(_cards[i].get("uid", ""))
	card_selected.emit(uid)
	_ui(&"hand_selected", {"uid": uid})
	_ui(&"card_zoomed", {"uid": uid})


func play_selected() -> bool:
	return _play_index(_selected, &"key")


func play_uid(uid: String) -> bool:
	for i in _cards.size():
		if str(_cards[i].get("uid", "")) == uid:
			return _play_index(i, &"auto")
	return false


func card_rect(uid: String) -> Rect2:
	for i in _cards.size():
		if str(_cards[i].get("uid", "")) == uid and i < _slots.size():
			var slot := _slots[i]
			return slot.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, CARD)
	return Rect2()


## 托盘（测试用）。
func preview_tray() -> Control:
	return _tray


func _build() -> void:
	if _band != null:
		return
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band = Control.new()
	_band.name = "Band"
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.size = CardLayout.FAN.size
	add_child(_band)
	CardAnchors.register(&"a.hand", _band, _band_rect)
	_kept_box = Control.new()
	_kept_box.name = "KeptBox"
	_kept_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_kept_box)
	_tray = Tray.new()
	_tray.name = "Tray"
	# 托盘画在各张牌上面（原型 #preview z 50 > #hand z 30），也就吃掉它下面的点击：
	# 选中后抬起的那张牌不再盖住放大牌的字，看见的就是点到的。
	_tray.mouse_filter = Control.MOUSE_FILTER_STOP
	_tray.visible = false
	add_child(_tray)
	_tray.setup(CardLayout.PREVIEW_CARD.grow(TRAY_PAD), CardLayout.PREVIEW_BTNS.grow(TRAY_PAD))
	_preview = CardWidget.new()
	_preview.name = "Preview"
	_preview._passive = true
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.visible = false
	add_child(_preview)
	_note = Label.new()
	_note.name = "HandNote"
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.position = Vector2(CENTER_X - 160.0, 640.0)
	_note.size = Vector2(320, 24)
	_note.add_theme_font_override("font", CardTheme.font_body())
	_note.add_theme_font_size_override("font_size", 14)
	_note.add_theme_color_override("font_color", CardTheme.color(&"text_3"))
	_note.visible = false
	add_child(_note)
	_drop_ring = Panel.new()
	_drop_ring.name = "DropRing"
	_drop_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_ring.position = DROP_RECT.position
	_drop_ring.size = DROP_RECT.size
	_drop_ring.visible = false
	add_child(_drop_ring)
	_drop_glow = Panel.new()
	_drop_glow.name = "DropGlow"
	_drop_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_glow.position = Vector2(4, 4)
	_drop_glow.size = DROP_RECT.size - Vector2(8, 8)
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color.TRANSPARENT
	glow.border_color = CardTheme.with_alpha(&"gold_glow", 0.22)
	glow.set_border_width_all(14)
	glow.set_corner_radius_all(6)
	glow.border_blend = true
	_drop_glow.add_theme_stylebox_override("panel", glow)
	_drop_glow.visible = false
	_drop_ring.add_child(_drop_glow)
	_drop_hint = Label.new()
	_drop_hint.name = "DropHint"
	_drop_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drop_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var hint_box := StyleBoxFlat.new()
	hint_box.bg_color = CardTheme.color(&"drop_bg")
	hint_box.border_color = CardTheme.color(&"drop_ring")
	hint_box.set_border_width_all(2)
	hint_box.set_corner_radius_all(10)
	hint_box.content_margin_left = 18.0
	hint_box.content_margin_right = 18.0
	hint_box.content_margin_top = 8.0
	hint_box.content_margin_bottom = 8.0
	_drop_hint.add_theme_stylebox_override("normal", hint_box)
	_drop_hint.add_theme_font_override("font", CardTheme.font_body())
	_drop_hint.add_theme_font_size_override("font_size", 16)
	_drop_hint.add_theme_color_override("font_color", CardTheme.color(&"gold_pale"))
	_drop_hint.visible = false
	add_child(_drop_hint)
	_buttons = Control.new()
	_buttons.name = "PreviewButtons"
	_buttons.position = CardLayout.PREVIEW_BTNS.position
	_buttons.size = CardLayout.PREVIEW_BTNS.size
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 按钮用卡牌版主题的变体（打出 PrimaryButton，其余木色 Button）；扇子自己挂一份，不靠根节点（b11）。
	_buttons.theme = CardTheme.build_theme()
	_buttons.visible = false
	add_child(_buttons)
	_play = _button("Play", "c02.btn.play", &"PrimaryButton", _on_play)
	_keep = _button("KeepSide", "c02.btn.keep", &"", _on_keep)
	_back = _button("Back", "c02.btn.back", &"", _on_back)
	CardAnchors.register(&"a.hand.preview", _play, _play_rect)
	set_process(false)
	_sync_band()


func _button(node_name: String, key: String, variation: StringName, cb: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.theme_type_variation = variation
	b.size = Vector2(CardLayout.PREVIEW_BTNS.size.x, BTN_H)
	b.text = CardText.ui(key)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(cb)
	_buttons.add_child(b)
	return b


## 树里的先后就是画的先后、点的先后：各张牌（悬停的那张最后）、托盘、放大牌、空手提示、拖拽提示、预览按钮。
## 托盘和放大牌在牌上面（原型 #preview 在 #hand 之上）：选中的牌停在悬停位时缩在托盘后面，不挡放大牌的字。
func _restack() -> void:
	for node in [_tray, _preview, _note, _drop_ring, _drop_hint, _buttons]:
		move_child(node as Node, get_child_count() - 1)


func _slot_base() -> int:
	return _kept_box.get_index() + 1


func _add_slot(i: int) -> void:
	var slot := Slot.new()
	slot.name = "FanCard%d" % i
	slot.fan = self
	slot.index = i
	slot.size = CARD
	slot.pivot_offset = PIVOT
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	var widget := CardWidget.new()
	widget.name = "Face"
	widget.bus = bus
	widget.set_size_mode(&"hand")
	widget.set_card(_face(_cards[i]))
	widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(widget)
	slot.mouse_entered.connect(_on_hover.bind(i))
	slot.mouse_exited.connect(_on_unhover.bind(i))
	slot.gui_input.connect(_on_slot_input.bind(i))
	add_child(slot)
	_slots.append(slot)


func _clear_cards() -> void:
	_hover = -1
	CardAnchors.unregister(&"a.hand.gold", _band)
	CardAnchors.unregister(&"a.hand.kept", _kept_box)
	for slot in _slots:
		CardAnchors.unregister(&"a.hand.gold", slot)
		if is_instance_valid(slot):
			if slot.get_parent() == self:
				remove_child(slot)
			slot.queue_free()
	_slots = []
	_cards = []


## 摆牌：sec > 0 时位置和角度补间过去（快动画直接到位）。悬停的牌点击区延到原来的位置（不闪、不换牌）。
func _layout_cards(sec: float) -> void:
	var n := _slots.size()
	for i in n:
		var slot := _slots[i]
		var hovered := i == _hover and not _away
		var spot := _place(i, n, _low, _away, hovered)
		var pos: Vector2 = spot["pos"]
		var rot := float(spot["rot"])
		slot.z_index = 0
		var s := slot as Slot
		if hovered:
			var rest: Dictionary = _place(i, n, _low, false, false)
			slot.size = Vector2(CARD.x, maxf(CARD.y, (rest["pos"] as Vector2).y + CARD.y - pos.y))
			if s != null:
				# 原位露出来的那一条：右边还有牌时宽一个牌距，最右一张整张
				var strip_w := CARD.x if i == n - 1 else minf(CARD.x, _spacing(n))
				s.rest_xform = Transform2D(0.0, (rest["pos"] as Vector2) + PIVOT) * Transform2D(deg_to_rad(float(rest["rot"])), Vector2.ZERO) \
					* Transform2D(0.0, -PIVOT)
				s.rest_strip = Rect2(Vector2.ZERO, Vector2(strip_w, CARD.y))
				s.lifted = true
		else:
			slot.size = CARD
			if s != null:
				s.lifted = false
		var alpha := 0.0 if _away else (0.25 if i == _drag_index else 1.0)
		_tween_slot(slot, pos, rot, alpha, sec)
		var face := slot.get_node_or_null("Face") as CardWidget
		if face != null:
			face.set_highlight(i == _selected or hovered)
			face.set_lifted(hovered)
			face.set_ring(_low and not _away and str(_cards[i].get("zone", "")) == "kept")


func _tween_slot(slot: Control, pos: Vector2, rot: float, alpha: float, sec: float) -> void:
	if slot.has_meta(&"tween"):
		var old: Variant = slot.get_meta(&"tween")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
		slot.remove_meta(&"tween")
	if sec <= 0.0 or _fast() or not slot.is_inside_tree():
		slot.position = pos
		slot.rotation_degrees = rot
		slot.modulate.a = alpha
		return
	if slot.position.is_equal_approx(pos) and is_equal_approx(slot.rotation_degrees, rot) \
			and is_equal_approx(slot.modulate.a, alpha):
		return
	var tw := slot.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(slot, "position", pos, sec)
	tw.tween_property(slot, "rotation_degrees", rot, sec)
	tw.tween_property(slot, "modulate:a", alpha, sec)
	slot.set_meta(&"tween", tw)


func _fast() -> bool:
	return fast_anim or _fast_setting


func _sync_marks() -> void:
	CardAnchors.unregister(&"a.hand.gold", _band)
	for slot in _slots:
		CardAnchors.unregister(&"a.hand.gold", slot)
	CardAnchors.unregister(&"a.hand.kept", _kept_box)
	if not _cards.is_empty() and bool(_cards[0].get("gold", false)) and not _slots.is_empty():
		CardAnchors.register(&"a.hand.gold", _slots[0], _clip_of.bind(_slots[0]))
	var box := Rect2()
	var any := false
	for i in _cards.size():
		if str(_cards[i].get("zone", "")) != "kept":
			continue
		var slot := _slots[i]
		var sr := Rect2(slot.position, CARD)
		box = sr if not any else box.merge(sr)
		any = true
	if any:
		_kept_box.position = box.position
		_kept_box.size = box.size
		_kept_box.visible = true
		CardAnchors.register(&"a.hand.kept", _kept_box, _clip_of.bind(_kept_box))
	else:
		_kept_box.visible = false


func _sync_preview() -> void:
	var show := _selected >= 0 and _selected < _cards.size() and not _away
	var was := _tray.visible
	_preview.visible = show
	_tray.visible = show
	_buttons.visible = show
	_play.visible = show
	_back.visible = show
	_back.text = CardText.ui("c02.btn.back")
	_keep.text = CardText.ui("c02.btn.keep")
	if not show:
		_keep.visible = false
		_play.text = CardText.ui("c02.btn.play")
		return
	var face := _face(_cards[_selected])
	_play.text = CardText.ui(_play_key(face))
	_preview._passive = true
	_preview.position = CardLayout.PREVIEW_CARD.position
	_preview.set_size_mode(&"zoom")
	_preview.set_card(face)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var on_card := _preview.get_node("Keep") as Button
	on_card.visible = false
	on_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keep.visible = _can_keep(face)
	# 按钮从下往上摆（原型 .pvwrap 底对齐）：放回手里在最下，往上是留着、打出。
	var y := CardLayout.PREVIEW_BTNS.size.y
	for b in [_back, _keep, _play]:
		var btn := b as Button
		if not btn.visible:
			continue
		y -= BTN_H
		btn.position = Vector2(0, y)
		btn.size = Vector2(CardLayout.PREVIEW_BTNS.size.x, BTN_H)
		y -= BTN_GAP
	if not was and not _fast():
		for node in [_tray, _preview, _buttons]:
			var c := node as CanvasItem
			c.modulate.a = 0.0
			c.create_tween().tween_property(c, "modulate:a", 1.0, PREVIEW_SEC)
	elif _fast():
		for node in [_tray, _preview, _buttons]:
			(node as CanvasItem).modulate.a = 1.0


## 主按钮的字照原型按牌换：人物“打出 · 请进门”，别的牌“打出 · 就办这件”，夜牌“今晚做这个”，睡了；留着的牌“打出”。
func _play_key(face: Dictionary) -> String:
	if _phase == "night" or str(face.get("zone", "")) == "night":
		return "c02.night.none" if str(face.get("def", "")) == "" else "c02.btn.play.night"
	if str(face.get("zone", "")) == "kept":
		return "c02.btn.play"
	if str(face.get("type", "")) == "person":
		return "c02.btn.play.person"
	return "c02.btn.play.other"


## 白天手上一张牌也没有：扇区中间一行“今天的牌都处理完了。”（原型 .handnote）。
func _sync_note() -> void:
	var show := _phase == "day" and _cards.is_empty() and not _away
	_note.visible = show
	_note.text = CardText.ui("c02.hand.empty_done") if show else ""


func _sync_band() -> void:
	if _band == null:
		return
	var y := CardLayout.FAN.position.y
	if _away:
		y = AWAY_TOP
	elif _low:
		y += LOW_DY
	_band.position = Vector2(CardLayout.FAN.position.x, y)


func _on_hover(i: int) -> void:
	if _hover == i or i < 0 or i >= _slots.size():
		return
	var old := _hover
	_hover = i
	if old >= 0 and old < _slots.size():
		move_child(_slots[old], _slot_base() + old)
	move_child(_slots[i], _slot_base() + _slots.size() - 1)
	_layout_cards(HOVER_SEC)


func _on_unhover(i: int) -> void:
	if _hover != i:
		return
	_hover = -1
	# mouse_exited 也会在牌被移出树（刷新、整个扇子释放）时发出，那时不能挪子节点：放回原来的先后留到这一帧末尾。
	if i >= 0 and i < _slots.size():
		_restore_order.call_deferred(_slots[i], i)
	_layout_cards(HOVER_SEC)


func _restore_order(slot: Control, i: int) -> void:
	if not is_instance_valid(slot) or slot.get_parent() != self or _hover == i:
		return
	if i < _slots.size() and _slots[i] == slot:
		move_child(slot, _slot_base() + i)
		if _hover >= 0 and _hover < _slots.size():
			move_child(_slots[_hover], _slot_base() + _slots.size() - 1)


func _on_slot_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			select_index(i)


func _on_play() -> void:
	_play_index(_selected, &"button")


func _on_keep() -> void:
	if _selected < 0 or _selected >= _slots.size():
		return
	var face := _slots[_selected].get_node_or_null("Face") as CardWidget
	if face == null or not _can_keep(_face(_cards[_selected])):
		return
	face.action_requested.emit(face.get_uid(), "keep")


func _on_back() -> void:
	_selected = -1
	_layout_cards(0.0)
	_sync_preview()


func _play_index(index: int, how: StringName) -> bool:
	if index < 0 or index >= _cards.size():
		return false
	var card: Dictionary = _cards[index]
	var uid := str(card.get("uid", ""))
	var def_id := str(card.get("def", ""))
	card_played.emit(uid, def_id, how)
	_ui(&"hand_played", {"uid": uid, "def": def_id, "how": str(how)})
	# 牌已经打出去，预览和“打出 / 放回手里”收起来，不留在开出的面板上面
	if _selected == index:
		_selected = -1
		_layout_cards(0.0)
		_sync_preview()
	return true


func _slot_drag(index: int, at_position: Vector2) -> Variant:
	if index < 0 or index >= _cards.size():
		return null
	var card: Dictionary = _cards[index]
	var uid := str(card.get("uid", ""))
	var zone := str(card.get("zone", "hand"))
	if zone == "" and _phase == "night":
		zone = "night"
	_ui(&"card_drag_started", {"uid": uid, "zone": zone})
	var slot := _slots[index]
	var face := slot.get_node_or_null("Face") as CardWidget
	_drag_index = index
	if slot.is_inside_tree() and slot.get_viewport().gui_is_dragging() and face != null:
		# 抬起的牌点击区往下延到原位：从延出来那块按下时，影子按牌里最近的一点抓。
		slot.set_drag_preview(face.make_ghost(at_position.clamp(Vector2(8, 8), CARD - Vector2(8, 8))))
		slot.modulate.a = 0.25
		# 按下时选中弹出了预览；拖起来以后收起，不压在场景中间（原型拖拽时没有预览）。
		if _selected == index:
			_selected = -1
			_sync_preview()
		_show_drop(zone != "kept")
	return {"kind": "card", "uid": uid, "zone": zone}


func _slot_drag_end(index: int) -> void:
	if index != _drag_index or index < 0 or index >= _slots.size():
		return
	_drag_index = -1
	_show_drop(false)
	var slot := _slots[index]
	slot.modulate.a = 0.0 if _away else 1.0
	if not slot.is_inside_tree():
		return
	if _over_fan(slot.get_global_mouse_position()):
		return
	_play_index(index, &"drag")


## 拖着手牌 / 夜牌时：场景外框亮起，鼠标出了扇区（放得下）时更亮；正中偏上一行提示（原型 .droplabel，#stage.dropover）。
func _show_drop(on: bool) -> void:
	_drop_ring.visible = on
	_drop_hint.visible = on
	_drop_hint.text = CardText.ui("c02.drag.drop_here") if on else ""
	set_process(on)
	if on:
		var w := _drop_hint.get_minimum_size()
		_drop_hint.size = w
		_drop_hint.position = Vector2(640.0 - w.x * 0.5, 720.0 * 0.38 - w.y * 0.5)
		_drop_over = false
		_style_drop_ring()


func _process(_delta: float) -> void:
	if _drag_index < 0:
		set_process(false)
		return
	var at := get_global_mouse_position()
	var over := not _over_fan(at) and DROP_RECT.has_point(at)
	if over != _drop_over:
		_drop_over = over
		_style_drop_ring()


func _style_drop_ring() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT
	sb.set_corner_radius_all(6)
	if _drop_over:
		# 原型 0 0 0 4px gold + 40px 金光：StyleBoxFlat 的影子会铺满整块，这里用一圈加宽的半透明边代替光。
		sb.border_color = CardTheme.color(&"drop_ring")
		sb.set_border_width_all(4)
		_drop_glow.visible = true
	else:
		sb.border_color = CardTheme.with_alpha(&"drop_ring", 0.5)
		sb.set_border_width_all(3)
		_drop_glow.visible = false
	_drop_ring.add_theme_stylebox_override("panel", sb)


func _over_fan(at: Vector2) -> bool:
	var zone := Rect2(CardLayout.FAN.position.x - 48.0, CardLayout.FAN.position.y, CardLayout.FAN.size.x + 96.0, 250.0)
	if _away:
		zone.position.y = AWAY_TOP
	elif _low:
		zone.position.y += LOW_DY
	return zone.has_point(at)


func _offer_card(offer: Variant) -> Dictionary:
	if typeof(offer) == TYPE_DICTIONARY:
		var entry: Dictionary = offer
		return {
			"uid": str(entry.get("uid", "")),
			"def": str(entry.get("def", "")),
			"type": "night",
			"zone": "night",
			"art": str(entry.get("art", "")),
			"choices": entry.get("choices", []),
		}
	return {"uid": "", "def": str(offer), "type": "night", "zone": "night", "art": ""}


func _face(card: Dictionary) -> Dictionary:
	var face := card.duplicate(true)
	if str(face.get("def", "")) == "" and _phase == "night":
		face["type"] = "night"
		face["zone"] = "night"
		face["_title_ui"] = "c02.night.none"
	return face


func _can_keep(card: Dictionary) -> bool:
	if bool(card.get("gold", false)):
		return false
	var actions: Variant = card.get("actions", [])
	if typeof(actions) != TYPE_ARRAY:
		return false
	for a in actions:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		if str(a.get("id", "")) == "keep" and bool(a.get("enabled", false)):
			return true
	return false


func _spacing(n: int) -> float:
	return minf(115.0, 492.0 / float(n - 1)) if n > 1 else 0.0


func _place(i: int, n: int, low: bool, away: bool, hover: bool) -> Dictionary:
	var spacing := _spacing(n)
	var mid := float(n - 1) * 0.5
	var denom := maxf(1.0, mid)
	var t := (float(i) - mid) / denom
	var angle := t * minf(6.0, 2.0 + 1.2 * float(n))
	var top := REST_TOP + float(roundi(16.0 * t * t))
	if hover and not away:
		top = HOVER_TOP
		angle = 0.0
	if low and not away:
		top += LOW_DY
	if away:
		top = AWAY_TOP
	var cx := CENTER_X + (float(i) - mid) * spacing
	return {"pos": Vector2(cx - CARD.x * 0.5, top), "rot": angle}


func _band_rect() -> Rect2:
	return _clip_of(_band)


func _play_rect() -> Rect2:
	return _clip_of(_play)


func _clip_of(node: Control) -> Rect2:
	if node == null or not node.is_inside_tree() or not node.is_visible_in_tree():
		return Rect2()
	var raw: Rect2 = node.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, node.size)
	return raw.intersection(CardLayout.SCREEN)


func _as_array(v: Variant) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []


func _ui(event_name: StringName, args: Dictionary) -> void:
	var event_bus := bus
	if event_bus == null and is_inside_tree():
		event_bus = get_node_or_null("/root/CardBus") as CardEventBus
	if event_bus != null:
		event_bus.ui_event.emit(event_name, args)
