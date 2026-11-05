# 柜台上的格子与铜钱。接口 CardChecksApi 的实现。主人 C03。
# 合同：docs/cards/CARDS_INTERFACES.md §7.11.7。空处鼠标穿透。
# 放进 / 拿出只发 slot.place / slot.remove，刷新推迟到本帧之后，避免在格子自己的信号里拆掉自己。
# 换皮（10-22，原型 58–62）：格子刚摆出来时整排从下面 8px 淡入（0.3 秒，快动画跳过）；铜钱一排：自动算正面的几枚
# 在前、带金圈，要掷的几枚压暗；旁边一句“铜钱 n 枚 · 要 m 个正面”（没有铜钱时“格子空着，没有铜钱”）。
# 选择器是深色小面板，摆在那一格上方，每样东西写名字（人带头像），最后一个“算了”。
class_name CardCounterChecks
extends CardChecksApi

const Face = preload("res://scripts/cards/ui/slots/coin_face.gd")
const Kit = preload("res://scripts/cards/ui/slots/drawer_kit.gd")
const PICK_W := 300.0
const SLOT_SCENE := preload("res://scenes/cards/slots/SlotWidget.tscn")
const COIN_SCENE := preload("res://scenes/cards/slots/CoinToss.tscn")

var engine: CardEngineApi = null
var bus: CardEventBus = null

var _uid: String = ""
var _preview: Dictionary = {}
var _slots_root: Control
var _coin_box: Control
var _reason: Label
var _picker: Panel
var _picker_slot: String = ""
var _toss: CardCoinTossView
var _shown: bool = false
var _refresh_queued: bool = false
var _view: Dictionary = {}
var _items: Array = []
## 这一把成没成：和引擎 toss_placed 同一算法（自动过，或正面数 + 自动正面 ≥ 要几个），掷完随 coins_finished 发出去。
var _toss_success: bool = false
var _fade: Tween = null


func _ready() -> void:
	_build()
	visible = _shown


func show_checks(card_uid: String) -> void:
	_build()
	_uid = card_uid
	_pull_view()
	_clear_slots()
	var queried := _query(&"slots", {"uid": _uid})
	_preview = queried.duplicate(true)
	var slot_views: Array = _rows(_preview.get("slots", []))
	var was_shown := _shown
	_shown = not slot_views.is_empty()
	visible = _shown
	if _shown and not was_shown:
		_fade_in()
	var money_registered := false
	for i in range(slot_views.size()):
		var slot_view: Dictionary = slot_views[i]
		var widget := SLOT_SCENE.instantiate() as CardSlotWidget
		widget.name = "Slot_%s" % str(slot_view.get("id", i))
		widget.bus = _event_bus()
		_slots_root.add_child(widget)
		widget.fit(CardLayout.slot_rect(i, slot_views.size()))
		widget.set_slot(_uid, _decorate(slot_view))
		var unit := _money_unit(slot_view)
		widget.set_money_unit(unit)
		widget.place_requested.connect(_on_place)
		widget.remove_requested.connect(_on_remove)
		widget.empty_pressed.connect(open_picker)
		widget.money_step.connect(_on_money_step)
		if i == 0:
			CardAnchors.register(&"a.slots.first", widget)
		if unit > 0 and not money_registered:
			CardAnchors.register(&"a.slots.money", widget.money_pad())
			money_registered = true
	_show_waiting_coins()
	if _shown:
		_coin_box.position = CardLayout.COINS.position
		_coin_box.size = CardLayout.COINS.size
		CardAnchors.register(&"a.slots.coins", _coin_box)


func hide_checks() -> void:
	_build()
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_slots_root.modulate.a = 1.0
	_slots_root.position = Vector2.ZERO
	_clear_slots()
	_close_picker()
	_uid = ""
	_preview = {}
	_shown = false
	visible = false
	if _toss != null:
		_toss.queue_free()
		_toss = null


func is_shown() -> bool:
	return _shown


func preview() -> Dictionary:
	var result := {}
	for key in ["coins", "auto_heads", "need", "auto_pass", "ready"]:
		if _preview.has(key):
			result[key] = _preview[key]
	return result


func play_coins(faces: Array, need: int) -> void:
	_build()
	_hide_waiting()
	_toss_success = _success_of(faces, need)
	if _toss == null or not is_instance_valid(_toss):
		_toss = COIN_SCENE.instantiate() as CardCoinTossView
		_toss.name = "CoinToss"
		_toss.position = Vector2.ZERO
		_toss.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toss.counter_layout = true
		add_child(_toss)
		_toss.finished.connect(_on_toss_finished)
	else:
		_toss.counter_layout = true
	_toss.auto_heads = 0 if bool(_preview.get("auto_pass", false)) else int(_preview.get("auto_heads", 0))
	_toss.play(faces, need)


func skip_coins() -> void:
	if _toss != null and is_instance_valid(_toss):
		_toss.skip()


func open_picker(slot_id: String) -> void:
	_build()
	_picker_slot = slot_id
	_close_picker()
	_picker_slot = slot_id
	_pull_view()
	_picker = Panel.new()
	_picker.name = "Picker"
	_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	_picker.add_theme_stylebox_override("panel", _picker_style())
	var col := VBoxContainer.new()
	col.name = "PickerList"
	col.position = Vector2(14, 12)
	col.custom_minimum_size = Vector2(PICK_W - 28.0, 0)
	col.add_theme_constant_override("separation", 6)
	_picker.add_child(col)
	var title := Kit.label(CardText.ui("c03.picker.title"), 15, &"gold_hi", true)
	title.name = "PickerTitle"
	col.add_child(title)
	_add_sources(col, slot_id)
	var cancel := Kit.small_button(CardText.ui("c03.picker.cancel"))
	cancel.name = "PickerCancel"
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cancel.pressed.connect(_close_picker)
	col.add_child(cancel)
	add_child(_picker)
	col.reset_size()
	var height := col.get_combined_minimum_size().y + 24.0
	_picker.size = Vector2(PICK_W, minf(400.0, height))
	var widget := _widget(slot_id)
	var anchor := Rect2(widget.position, widget.size) if widget != null else CardLayout.SLOTS
	var x := anchor.position.x + (anchor.size.x - PICK_W) * 0.5
	var y := anchor.position.y - _picker.size.y - 8.0
	_picker.position = Vector2(clampf(x, 8.0, 1272.0 - PICK_W), clampf(y, 36.0, maxf(36.0, 680.0 - _picker.size.y)))


func _picker_style() -> StyleBox:
	var sb := CardTheme.flat_style(&"modal_bot", &"gold_deep", 2, 6, 0.0, 0.0)
	sb.bg_color = CardTheme.mix(&"modal_top", &"modal_bot")
	sb.shadow_color = CardTheme.color(&"modal_shadow")
	sb.shadow_size = 16
	sb.shadow_offset = Vector2(0, 6)
	return sb


func offer(slot_id: String, source: Dictionary) -> void:
	var widget := _widget(slot_id)
	if widget == null:
		return
	widget.offer(source)


func show_reason(result: Dictionary) -> void:
	_build()
	var key := str(result.get("reason_key", ""))
	if key == "":
		key = "c03.err." + str(result.get("err", "unknown"))
	_reason.text = CardText.t(key)
	_reason.visible = true


func clear_reason() -> void:
	if _reason == null:
		return
	_reason.text = ""
	_reason.visible = false


func _build() -> void:
	if _slots_root != null:
		return
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slots_root = Control.new()
	_slots_root.name = "Slots"
	_slots_root.size = size
	_slots_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slots_root)
	_coin_box = Control.new()
	_coin_box.name = "CoinRow"
	_coin_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_box.position = CardLayout.COINS.position
	_coin_box.size = CardLayout.COINS.size
	add_child(_coin_box)
	_reason = Kit.label("", 15, &"flash_bad_ink")
	_reason.name = "Reason"
	_reason.visible = false
	_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason.add_theme_stylebox_override("normal", CardTheme.pill_style(&"flash_bg", &"flash_bad_edge", 6, 12.0, 3.0))
	_reason.position = Vector2(CardLayout.SLOTS.position.x, CardLayout.SLOTS.position.y - 34)
	_reason.size = Vector2(CardLayout.SLOTS.size.x, 28)
	add_child(_reason)


func _clear_slots() -> void:
	if _coin_box != null:
		CardAnchors.unregister(&"a.slots.coins", _coin_box)
	for child in _slots_root.get_children():
		if child is CardSlotWidget:
			CardAnchors.unregister(&"a.slots.first", child)
			CardAnchors.unregister(&"a.slots.money", (child as CardSlotWidget).money_pad())
		_slots_root.remove_child(child)
		child.queue_free()
	_hide_waiting()


func _show_waiting_coins() -> void:
	_hide_waiting()
	if bool(_preview.get("auto_pass", false)):
		return
	var coins := maxi(0, int(_preview.get("coins", 0)))
	var autos := maxi(0, int(_preview.get("auto_heads", 0)))
	var total := mini(CardLayout.COIN_MAX, coins + autos)
	autos = mini(autos, total)
	for i in range(total):
		var coin = Face.new()
		var auto := i < autos
		coin.name = ("WaitAuto%d" % i) if auto else ("WaitCoin%d" % (i - autos))
		coin.idle_face = true
		coin.face = true
		coin.shown = auto
		coin.ring = auto
		if not auto:
			coin.modulate = CardTheme.with_alpha(&"text_3", 0.55)
		var rect := CardLayout.coin_rect(i, total)
		coin.position = rect.position
		coin.size = rect.size
		add_child(coin)
	var key := "c03.coins.line" if total > 0 else "c03.coins.none"
	var line := Kit.label(CardText.ui(key, {"n": coins, "m": int(_preview.get("need", 0))}), 14, &"text_2")
	line.name = "CoinsLine"
	line.add_theme_stylebox_override("normal", CardTheme.pill_style(&"drop_bg", &"", 6, 10.0, 2.0))
	add_child(line)
	line.reset_size()
	var lsz := line.get_combined_minimum_size()
	var row := CardLayout.COINS
	if total > 0:
		var last := CardLayout.coin_rect(total - 1, total)
		line.position = Vector2(last.end.x + 16.0, last.position.y + (last.size.y - lsz.y) * 0.5)
	else:
		line.position = Vector2(row.position.x + (row.size.x - lsz.x) * 0.5, row.position.y + (row.size.y - lsz.y) * 0.5)


func _hide_waiting() -> void:
	for child in get_children():
		var node_name := str(child.name)
		if node_name.begins_with("WaitCoin") or node_name.begins_with("WaitAuto") or node_name == "CoinsLine":
			remove_child(child)
			child.queue_free()


## 格子刚摆出来：整排从下面 8px 淡入 0.3 秒（原型 .slot 出现）；快动画直接到位。
func _fade_in() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if CardSettings.fast_anim() or not is_inside_tree():
		_slots_root.modulate.a = 1.0
		_slots_root.position = Vector2.ZERO
		return
	_slots_root.modulate.a = 0.0
	_slots_root.position = Vector2(0, 8)
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(_slots_root, "modulate:a", 1.0, 0.3)
	_fade.tween_property(_slots_root, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_place(slot_id: String, source: Dictionary) -> void:
	if engine == null:
		return
	var result := engine.send(&"slot.place", {"uid": _uid, "slot": slot_id, "source": source.duplicate(true)})
	if bool(result.get("ok", false)):
		clear_reason()
		_queue_refresh()
	else:
		show_reason(result)
		changed.emit()


func _on_remove(slot_id: String, index: int) -> void:
	if engine == null:
		return
	var result := engine.send(&"slot.remove", {"uid": _uid, "slot": slot_id, "index": index})
	if bool(result.get("ok", false)):
		clear_reason()
		_queue_refresh()
	else:
		show_reason(result)
		changed.emit()


func _on_money_step(slot_id: String, sign: int) -> void:
	var widget := _widget(slot_id)
	if widget == null:
		return
	var unit := widget.money_unit()
	if unit <= 0:
		unit = 10
	if sign > 0:
		widget.offer({"kind": "money", "amount": unit})
		return
	var placed: Array = _rows(_slot_of(slot_id).get("placed", []))
	for i in range(placed.size() - 1, -1, -1):
		if str(placed[i].get("kind", "")) == "money":
			_on_remove(slot_id, i)
			return


func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh_later.call_deferred()


func _refresh_later() -> void:
	_refresh_queued = false
	if _uid == "":
		return
	var slot := _picker_slot
	show_checks(_uid)
	if slot != "" and _picker != null:
		open_picker(slot)
	changed.emit()


func _on_toss_finished() -> void:
	coins_finished.emit(_toss_success)


## 最近一次 query("slots") 的自动正面、自动过（放进去的东西给的）加上这一把掷出的正面（合同 §7.11.7）。
func _success_of(faces: Array, need: int) -> bool:
	if bool(_preview.get("auto_pass", false)):
		return true
	var heads := int(_preview.get("auto_heads", 0))
	for face in faces:
		if bool(face):
			heads += 1
	return heads >= need


func _add_sources(col: VBoxContainer, slot_id: String) -> void:
	var accepts: Array = _rows(_slot_of(slot_id).get("accepts", []))
	if accepts.has("self") or accepts.is_empty():
		var self_view: Dictionary = _view.get("self", {}) if typeof(_view.get("self")) == TYPE_DICTIONARY else {}
		var btn := _source_button("PickSelf", CardText.ui("c03.picker.self"), {"kind": "self"}, _self_art(self_view))
		btn.disabled = bool(self_view.get("used_today", false))
		if btn.disabled:
			btn.tooltip_text = CardText.ui("c03.picker.used")
		col.add_child(btn)
	for row in _rows(_view.get("contacts", [])):
		var uid := str(row.get("uid", ""))
		if not accepts.is_empty() and not accepts.has("contact"):
			break
		var btn := _source_button("Pick_contact_%s" % uid, _person_label(row), {"kind": "contact", "uid": uid},
			str(row.get("art", "")))
		btn.disabled = bool(row.get("used_today", false)) or int(row.get("away_days", 0)) > 0
		if btn.disabled:
			btn.tooltip_text = CardText.ui("c03.picker.away" if int(row.get("away_days", 0)) > 0 else "c03.picker.used")
		col.add_child(btn)
	for row in _rows(_view.get("kept", [])):
		if not accepts.is_empty() and not accepts.has("kept"):
			break
		var uid := str(row.get("uid", ""))
		col.add_child(_source_button("Pick_kept_%s" % uid, _card_label(row, "c03.picker.kept"),
			{"kind": "kept", "uid": uid}, ""))
	if accepts.has("item") or accepts.is_empty():
		for it in _items:
			if typeof(it) != TYPE_DICTIONARY:
				continue
			var item := str(it.get("item", ""))
			col.add_child(_source_button("PickItem_%s" % item, _item_label(it), {"kind": "item", "item": item}, ""))
	for row in _rows(_view.get("hand", [])):
		if str(row.get("type", "")) != "news":
			continue
		if not accepts.is_empty() and not accepts.has("news"):
			break
		var uid := str(row.get("uid", ""))
		col.add_child(_source_button("Pick_news_%s" % uid, _card_label(row, "c03.picker.news"),
			{"kind": "news", "uid": uid}, ""))
	if accepts.has("money") or accepts.is_empty():
		col.add_child(_source_button("PickMoney", CardText.ui("c03.picker.money"), {"kind": "money", "amount": 20}, ""))


func _source_button(node_name: String, text: String, source: Dictionary, art: String) -> Button:
	var btn := Button.new()
	btn.name = node_name
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.clip_text = true
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.focus_mode = Control.FOCUS_ALL
	btn.custom_minimum_size = Vector2(PICK_W - 28.0, 40)
	btn.add_theme_font_override("font", CardTheme.font_body())
	btn.add_theme_font_size_override("font_size", 15)
	var face := _face_icon(art)
	if face != null:
		btn.icon = face
	btn.pressed.connect(_press_source.bind(source, btn))
	return btn


## 人在选择器里带一小块头像（头像上半截 28x28，原大）。
func _face_icon(art: String) -> Texture2D:
	if art == "":
		return null
	var tex := CardArt.texture(art)
	if tex == null:
		return null
	var base := CardArt.base_size(art)
	if base == Vector2i.ZERO:
		base = Vector2i(tex.get_width(), tex.get_height())
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(float(base.x - 28) * 0.5, 0.0, mini(28, base.x), mini(28, base.y))
	return at


func _self_art(self_view: Dictionary) -> String:
	var art := str(self_view.get("art", ""))
	if art != "":
		return art
	var def_id := str(self_view.get("def", ""))
	return "portrait." + def_id.substr(5) if def_id.begins_with("self.") else ""


func _person_label(row: Dictionary) -> String:
	var def_id := str(row.get("def", ""))
	if def_id != "":
		return CardText.card(def_id, "title")
	var who := str(row.get("person", ""))
	return CardText.person_name(who) if who != "" else CardText.ui("c03.picker.contact")


func _card_label(row: Dictionary, fallback: String) -> String:
	var def_id := str(row.get("def", ""))
	return CardText.card(def_id, "title") if def_id != "" else CardText.ui(fallback)


func _item_label(it: Dictionary) -> String:
	var template := str(it.get("template", ""))
	return CardText.item_text(template, "name") if template != "" else CardText.ui("c03.picker.item")


func _press_source(source: Dictionary, btn: Button) -> void:
	if btn.disabled or _picker_slot == "":
		return
	offer(_picker_slot, source)
	_close_picker()


func _close_picker() -> void:
	if _picker != null and is_instance_valid(_picker):
		_picker.queue_free()
	_picker = null


func _widget(slot_id: String) -> CardSlotWidget:
	var node := _slots_root.get_node_or_null("Slot_%s" % slot_id) if _slots_root != null else null
	return node as CardSlotWidget


func _slot_of(slot_id: String) -> Dictionary:
	for row in _rows(_preview.get("slots", [])):
		if str(row.get("id", "")) == slot_id:
			return row
	return {}


func _money_unit(slot_view: Dictionary) -> int:
	var accepts: Array = _rows(slot_view.get("accepts", []))
	if not accepts.has("money"):
		return 0
	if slot_view.has("money_per_coin"):
		return maxi(1, int(slot_view.get("money_per_coin", 10)))
	return 10


func _pull_view() -> void:
	_view = {}
	_items = []
	if engine == null:
		return
	var view = engine.view()
	if typeof(view) == TYPE_DICTIONARY:
		_view = view
	var stock := _query(&"stock", {})
	var items = stock.get("items", [])
	if typeof(items) == TYPE_ARRAY:
		_items = items


func _decorate(row: Dictionary) -> Dictionary:
	var copy := row.duplicate(true)
	var placed: Array = []
	for item in _rows(copy.get("placed", [])):
		var one: Dictionary = item.duplicate(true)
		if str(one.get("art", "")) == "":
			one["art"] = _art_of(one)
		if str(one.get("label", "")) == "":
			one["label"] = _label_of(one)
		placed.append(one)
	copy["placed"] = placed
	return copy


func _art_of(row: Dictionary) -> String:
	if str(row.get("kind", "")) == "item":
		for it in _items:
			if typeof(it) == TYPE_DICTIONARY and str(it.get("item", "")) == str(row.get("item", "")):
				return str(it.get("art", ""))
		return ""
	if str(row.get("kind", "")) == "self":
		var self_view = _view.get("self", {})
		if typeof(self_view) == TYPE_DICTIONARY:
			return str(self_view.get("art", ""))
	return _art_in(str(row.get("uid", "")))


## 格子里那样东西的名字：你自己、人脉的名字、牌名、物品名、多少钱。
func _label_of(row: Dictionary) -> String:
	match str(row.get("kind", "")):
		"self":
			return CardText.ui("c03.picker.self")
		"money":
			var money: Dictionary = _view.get("money", {}) if typeof(_view.get("money")) == TYPE_DICTIONARY else {}
			var unit := CardText.ui("c01.money.unit." + str(money.get("currency", "fabi")))
			return CardText.ui("c03.slot.money", {"n": int(row.get("amount", 0)), "unit": unit})
		"item":
			for it in _items:
				if typeof(it) == TYPE_DICTIONARY and str(it.get("item", "")) == str(row.get("item", "")):
					return _item_label(it)
			return ""
	var uid := str(row.get("uid", ""))
	for key in ["contacts", "kept", "hand", "pending"]:
		for one in _rows(_view.get(key, [])):
			if str(one.get("uid", "")) == uid:
				return _person_label(one) if key == "contacts" else _card_label(one, "c03.picker.kept")
	return ""


func _art_in(uid: String) -> String:
	for key in ["hand", "kept", "contacts", "pending"]:
		for row in _rows(_view.get(key, [])):
			if str(row.get("uid", "")) == uid:
				return str(row.get("art", ""))
	return ""


func _query(q: StringName, args: Dictionary) -> Dictionary:
	if engine == null:
		return {}
	var result = engine.query(q, args)
	return result if typeof(result) == TYPE_DICTIONARY else {}


func _rows(raw) -> Array:
	return raw if typeof(raw) == TYPE_ARRAY else []


func _event_bus() -> CardEventBus:
	if bus != null:
		return bus
	if engine != null and engine.bus != null:
		return engine.bus
	return get_node_or_null("/root/CardBus") as CardEventBus if is_inside_tree() else null
