# 远洋战役的高清事务面板：营地上除剧情牌、战场牌以外的牌（挂牌、街区、后门、资源、行军、周历、名册、账簿、
# 大命运、催逼、道具、行军箱物件、伙伴）打出来开这里。远洋战役开着时，宿主把 slots / read 两种面板换成它
# （modal_host.overrides，kind 不变）；旧版战役照旧用像素的格子面板。
# 满屏：这一场的背景压暗，左边一张文书（圆章、小标题、标题、正文；办过以后下面写结果），右边是选项（和剧情 VN 的
# 抉择菜单同一套按钮，灰的写原因，数字键 1–9 也能选），底下“稍后再来”。大命运是红色的版本（战场远景、红边）。
# 只读 engine.query(card / campaign) 和 engine.view()，只发 card.choose（只读的牌不发指令）。
# 字：牌的标题、正文、选项来自 CardText（ocean_view 覆盖层）；界面字在 data/hd/hub_ui.json。没有 class_name。
extends CardPanel

const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const HdPlaceholder = preload("res://scripts/cards/ui/hd/hd_placeholder.gd")
const Data = preload("res://scripts/cards/ui/hub/hub_data.gd")
const Kit = preload("res://scripts/cards/ui/hub/hub_kit.gd")
const Deco = preload("res://scripts/cards/ui/vn/vn_deco.gd")
const W = preload("res://scripts/cards/ui/battle/hud/hud_widgets.gd")

const CMD := &"card.choose"
const DOC := Rect2(60, 60, 512, 600)
const DOC_READ := Rect2(250, 52, 780, 560)
const MENU := Rect2(612, 60, 608, 600)
const COINS := ["gold", "supply", "medal", "intel"]
const SIDE_LABELS := ["signage", "town", "backdoor", "resources", "march", "calendar", "squad", "status", "big_fate"]
const DOC_MIN_H := 420.0
const RULES_DEF := "ocean.rules"

## 宿主按登记的 kind 设（slots / read / help）
var kind: StringName = &"slots"
var fast := false

var _uid := ""
var _def := ""
var _read_only := false
var _closed := false
var _busy := false
var _chosen := 0
var _gone := false
var _result_lines: Array = []

var _built := false
var _doc: PanelContainer
var _medal_slot: Control
var _kicker: Label
var _title: Label
var _body: Label
var _body_scroll: ScrollContainer
var _result: PanelContainer
var _result_box: VBoxContainer
var _menu_root: Control
var _prompt: Label
var _choice_scroll: ScrollContainer
var _menu: VBoxContainer
var _tail: HBoxContainer
var _btn_later: Button


# ================================================================ 面板合同

func open(args: Dictionary) -> void:
	_closed = false
	_uid = str(args.get("uid", ""))
	_def = str(args.get("def", ""))
	# F1 / 暂停里的“帮助”：远洋战役开的是经营须知（高清，只读）
	if kind == &"help" and _uid == "" and _def == "":
		_def = RULES_DEF
	var host := get_parent()
	if host != null and "fast" in host:
		fast = fast or bool(host.get("fast"))
	var cv := _card()
	if _uid != "":
		if cv.is_empty():
			_close.call_deferred({})
			return
		_def = str(cv.get("def", _def))
	if _def == "":
		_close.call_deferred({})
		return
	_read_only = kind == &"read" or str(args.get("mode", "")) == "read" or _uid == "" or str(cv.get("panel", "")) == "read"
	_build()
	_fill_doc(cv)
	_rebuild()
	if not fast:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.2)


func refresh(_view: Dictionary) -> void:
	if _closed or _busy or not _built:
		return
	_rebuild.call_deferred()


func dismiss() -> void:
	_close({})


func autoplay_step() -> bool:
	if _closed:
		return false
	if not _read_only and _chosen == 0:
		for b in choice_buttons():
			if not b.disabled:
				b.pressed.emit()
				return true
	_close({})
	return true


## 选项按钮（按显示顺序；“稍后再来”不算）
func choice_buttons() -> Array[Button]:
	var out: Array[Button] = []
	if _menu == null:
		return out
	for b in _menu.get_children():
		if b is Button and b.has_meta("reply_id"):
			out.append(b)
	return out


func result_text() -> String:
	return "\n".join(PackedStringArray(_result_lines))


# ================================================================ 文书

func _fill_doc(cv: Dictionary) -> void:
	var spec := Data.card_spec(_uid if _uid != "" else "rules")
	Kit.clear(_medal_slot)
	var medal := Kit.medal("hub_" + (_uid.get_slice(":", 0) if _uid != "" else "rules"), str(spec.get("icon", "")), 58)
	_medal_slot.add_child(medal)
	_kicker.text = str(spec.get("kicker", ""))
	var title := CardText.card(_def, "title")
	# 营地事务和大命运用营地上的短名字（覆盖层的标题带英文副名）
	if _uid in SIDE_LABELS and str(spec.get("label", "")) != "":
		title = str(spec.get("label", ""))
	_title.text = title if title != "" else str(spec.get("label", ""))
	var body := Data.unpage(CardText.card(_def, "body"))
	# 经营须知：覆盖层里那段还在说“打出金色剧情牌”，营地上换成说真按钮的那一版
	if _def == RULES_DEF and Data.text("rules_body") != "":
		body = Data.text("rules_body")
	var use := Data.unpage(CardText.card(_def, "use"))
	if use != "" and use != body and _read_only:
		body += "\n" + use
	_body.text = body.strip_edges()
	var red := _uid == "big_fate"
	_kicker.add_theme_color_override(&"font_color", HdTheme.color("hd_enemy_hi" if red else "hd_gold"))
	if cv.get("days_left", -1) is int and int(cv.get("days_left", -1)) >= 0 and _uid.begins_with("demand:"):
		_kicker.text += Data.text("sep") + Data.text("demand_days", {"n": int(cv.get("days_left", 0))})


# ================================================================ 选项

func _rebuild() -> void:
	if _closed or not _built:
		return
	var cv := _card() if _uid != "" else {}
	if _uid != "" and (cv.is_empty() or not _in_view(_uid)):
		_gone = true
		cv = {}
	Kit.clear(_menu)
	if _read_only:
		_menu_root.visible = false
		_btn_later.text = Data.text("panel_close")
		_place_tail_read()
		return
	_menu_root.visible = true
	_prompt.visible = not _gone
	var n := 0
	for c in cv.get("choices", []):
		if typeof(c) != TYPE_DICTIONARY:
			continue
		n += 1
		_menu.add_child(_choice_button(c, n))
	if n == 0:
		var none := Kit.wrap(Data.text("panel_gone") if _gone else Data.text("panel_no_choice"), 17, "serif", "hd_text_2")
		none.custom_minimum_size = Vector2(MENU.size.x, 0)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_menu.add_child(none)
	_btn_later.text = Data.text("panel_back") if (_gone or _chosen > 0) else Data.text("panel_later")
	HdTheme.apply_button(_btn_later, "primary" if _gone else "ghost")
	_btn_later.custom_minimum_size = Vector2(170, 40)
	_menu.reset_size()
	_layout_columns(_prompt.size.y + 14.0 + _menu.get_combined_minimum_size().y + 18.0 + 44.0)


func _choice_button(c: Dictionary, n: int) -> Button:
	var id := str(c.get("id", ""))
	var enabled := bool(c.get("enabled", true))
	var b := Button.new()
	b.name = "Choice_" + id.replace(":", "_")
	var label := CardText.card(_def, "choices." + id)
	b.text = label if label != "" else id
	HdTheme.apply_button(b, "choice")
	b.add_theme_font_size_override(&"font_size", 18)
	b.custom_minimum_size = Vector2(0, 48)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for st in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var sb := b.get_theme_stylebox(st)
		if sb != null:
			sb.content_margin_left = 54
			sb.content_margin_right = 24
	# 灰的选项：底几乎不透（背后的图不从格子里透出来），只靠字色和暗边区分
	var off := HdTheme.box({"fill": ["hd_ink", 0.9], "edge": ["hd_gold", 0.16], "bw": 1, "r": 6, "pad": [54, 12]})
	off.content_margin_right = 24
	b.add_theme_stylebox_override(&"disabled", off)
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	b.set_meta("reply_id", id)
	b.pressed.connect(_on_choice.bind(id))
	var key := Kit.label(str(n) if n <= 9 else "", 13, "num", "hd_gold")
	key.name = "Key"
	key.modulate.a = 0.8 if enabled else 0.35
	b.add_child(key)
	key.position = Vector2(22, 14)
	if not enabled:
		var why := _reason(c)
		b.tooltip_text = why
		var tag := Kit.label(why, 12, "sans", "hd_warn")
		tag.name = "Reason"
		tag.modulate.a = 0.75
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_child(tag)
		tag.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.offset_left = -220
		tag.offset_right = -18
		b.add_theme_color_override(&"font_disabled_color", HdTheme.alpha("hd_text_3", 0.9))
		for st in [&"disabled"]:
			var sb := b.get_theme_stylebox(st)
			if sb != null:
				sb.content_margin_right = 230
	return b


func _reason(c: Dictionary) -> String:
	var phase := str(_view().get("phase", ""))
	if phase != "day":
		return Data.text("reason.bad_phase")
	return Data.text("reason.locked")


func _on_choice(id: String) -> void:
	if _busy or _closed or engine == null:
		return
	var label := CardText.card(_def, "choices." + id)
	var before := _snapshot()
	_busy = true
	var res: Dictionary = engine.send(CMD, {"uid": _uid, "choice": id})
	_busy = false
	if _closed:
		return
	_chosen += 1
	var lines: Array = [Data.text("panel_done", {"label": label if label != "" else id})]
	if not bool(res.get("ok", false)):
		lines = [Data.text("panel_error", {"err": str(res.get("err", ""))})]
	else:
		lines.append_array(_changes(before, _snapshot()))
	_show_result(lines)
	_rebuild()


func _show_result(lines: Array) -> void:
	_result_lines = lines
	Kit.clear(_result_box)
	var head := Kit.label(Data.text("panel_result"), 14, "sans_bold", "hd_gold")
	_result_box.add_child(head)
	for i in lines.size():
		var l := Kit.wrap(str(lines[i]), 16 if i == 0 else 15, "serif", "hd_text" if i == 0 else "hd_text_2")
		# 自动换行的字给实际宽度：宽度是 1 时第一帧的最小高度会按一字一行算，把文书撑出屏幕
		l.custom_minimum_size = Vector2(DOC.size.x - 96, 0)
		_result_box.add_child(l)
	_result.visible = true
	if not fast:
		_result.modulate.a = 0.0
		_result.create_tween().tween_property(_result, "modulate:a", 1.0, 0.25)


# ================================================================ 结算

func _snapshot() -> Dictionary:
	var c: Dictionary = engine.query(&"campaign") if engine != null else {}
	var kept := {}
	for row in _view().get("kept", []):
		if typeof(row) == TYPE_DICTIONARY:
			kept[str(row.get("uid", ""))] = str(row.get("def", ""))
	return {"gauges": c.get("gauges", []), "coins": c.get("coins", {}), "kept": kept, "chapter": str(c.get("chapter_id", ""))}


func _changes(before: Dictionary, after: Dictionary) -> Array:
	var parts := PackedStringArray()
	var old := {}
	for g in before["gauges"]:
		old[str(g.get("id", ""))] = int(g.get("amount", 0))
	var same_chapter := str(before["chapter"]) == str(after["chapter"])
	for g in after["gauges"]:
		var gid := str(g.get("id", ""))
		if gid == "treasury" and not same_chapter:
			continue
		var d := int(g.get("amount", 0)) - int(old.get(gid, int(g.get("amount", 0))))
		if d != 0:
			parts.append(Data.text("change", {"label": str(g.get("label", gid)), "delta": "%+d" % d}))
	var cb: Dictionary = before["coins"] if typeof(before["coins"]) == TYPE_DICTIONARY else {}
	var ca: Dictionary = after["coins"] if typeof(after["coins"]) == TYPE_DICTIONARY else {}
	for id in COINS:
		var d := int(ca.get(id, 0)) - int(cb.get(id, 0))
		if d != 0:
			parts.append(Data.text("change", {"label": Data.text("coin." + id), "delta": "%+d" % d}))
	var out: Array = [Data.text("change_sep").join(parts) if not parts.is_empty() else Data.text("panel_none")]
	var got := PackedStringArray()
	var lost := PackedStringArray()
	var kb: Dictionary = before["kept"]
	var ka: Dictionary = after["kept"]
	for uid in ka:
		if not kb.has(uid):
			got.append(CardText.card(str(ka[uid]), "title"))
	for uid in kb:
		if not ka.has(uid):
			lost.append(CardText.card(str(kb[uid]), "title"))
	if not got.is_empty():
		out.append(Data.text("items_in", {"names": Data.text("list_sep").join(got)}))
	if not lost.is_empty():
		out.append(Data.text("items_out", {"names": Data.text("list_sep").join(lost)}))
	return out


# ================================================================ 键

func _unhandled_input(event: InputEvent) -> void:
	if _closed or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var code := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
	if code >= KEY_1 and code <= KEY_9 and not _read_only:
		var buttons := choice_buttons()
		var i := code - KEY_1
		if i < buttons.size() and not buttons[i].disabled:
			buttons[i].pressed.emit()
		_handled()
	elif code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] and (_read_only or _gone):
		_close({})
		_handled()


func _handled() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()


func _close(result: Dictionary) -> void:
	if _closed:
		return
	_closed = true
	close_requested.emit(result)


func _card() -> Dictionary:
	if engine == null or _uid == "":
		return {}
	var r = engine.query(&"card", {"uid": _uid})
	return r if typeof(r) == TYPE_DICTIONARY else {}


## 这张牌还在不在桌上（手牌、留存、人脉）：大命运处理完、催逼交付完就不在了
func _in_view(uid: String) -> bool:
	var v := _view()
	for zone in ["hand", "kept", "contacts", "demands"]:
		for c in v.get(zone, []):
			if typeof(c) == TYPE_DICTIONARY and str(c.get("uid", "")) == uid:
				return true
	return false


func _view() -> Dictionary:
	if engine == null:
		return {}
	var raw = engine.view()
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


# ================================================================ 搭界面

func _build() -> void:
	if _built:
		return
	_built = true
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	HdTheme.apply_hd_filter(self)
	var base := ColorRect.new()
	base.color = HdTheme.color("hd_ink")
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.size = size
	add_child(base)
	var bg_id := "battle_backdrop" if _uid == "big_fate" else ""
	var bg_variant := ""
	if bg_id == "":
		var c: Dictionary = engine.query(&"campaign") if engine != null else {}
		var spec := Data.scene_bg(str(c.get("scene_id", "")))
		bg_id = str(spec.get("id", "camp_tent"))
		bg_variant = str(spec.get("variant", ""))
		if _uid in ["squad", "calendar", "march"]:
			bg_id = "camp_tent"
			bg_variant = ""
	var bg := HdPlaceholder.make_bg(bg_id if bg_id != "" else "camp_tent", "", "", bg_variant)
	bg.name = "Bg_" + (bg_id if bg_id != "" else "camp_tent")
	if HdPlaceholder.is_placeholder(bg):
		bg.set("title_alpha", 0.0)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := Deco.new().setup("dim")
	dim.size = size
	add_child(dim)
	var red := _uid == "big_fate"
	var doc_rect := DOC_READ if _read_only else DOC
	_doc = PanelContainer.new()
	_doc.name = "Doc"
	_doc.mouse_filter = Control.MOUSE_FILTER_PASS
	var box := HdTheme.panel_box("glass_strong")
	if red and box.has_method("outer"):
		var outer: StyleBoxFlat = box.call("outer")
		outer.border_color = HdTheme.alpha("hd_enemy_hi", 0.85)
		outer.shadow_color = HdTheme.alpha("hd_enemy", 0.35)
		outer.shadow_size = 24
	box.content_margin_left = 28
	box.content_margin_right = 24
	box.content_margin_top = 22
	box.content_margin_bottom = 20
	_doc.add_theme_stylebox_override(&"panel", box)
	_doc.position = doc_rect.position
	_doc.size = doc_rect.size
	_doc.custom_minimum_size = doc_rect.size
	add_child(_doc)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_doc.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 16)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	_medal_slot = Control.new()
	_medal_slot.custom_minimum_size = Vector2(58, 58)
	_medal_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_medal_slot)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override(&"separation", 2)
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(titles)
	_kicker = Kit.label("", 13, "sans_bold", "hd_gold")
	_kicker.name = "Kicker"
	_kicker.add_theme_font_override(&"font", HdTheme.font("sans_bold", 3))
	titles.add_child(_kicker)
	_title = Kit.wrap("", 27, "title", "hd_text")
	_title.name = "Title"
	_title.custom_minimum_size = Vector2(doc_rect.size.x - 140, 0)
	titles.add_child(_title)
	var rule := W.Rule.new()
	rule.custom_minimum_size = Vector2(0, 10)
	col.add_child(rule)
	_body_scroll = ScrollContainer.new()
	_body_scroll.name = "BodyScroll"
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(_body_scroll)
	_body = Kit.wrap("", 18, "serif", "hd_text")
	_body.name = "Body"
	_body.custom_minimum_size = Vector2(doc_rect.size.x - 80, 0)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override(&"line_spacing", 7)
	_body_scroll.add_child(_body)
	_result = PanelContainer.new()
	_result.name = "Result"
	_result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rbox := HdTheme.panel_box("header")
	rbox.content_margin_top = 10
	rbox.content_margin_bottom = 10
	_result.add_theme_stylebox_override(&"panel", rbox)
	_result_box = VBoxContainer.new()
	_result_box.add_theme_constant_override(&"separation", 4)
	_result_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result.add_child(_result_box)
	_result.visible = false
	col.add_child(_result)
	# 右边：选项
	_menu_root = Control.new()
	_menu_root.name = "Menu"
	_menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_root.size = size
	add_child(_menu_root)
	_prompt = Kit.label(Data.text("panel_prompt"), 28, "title", "hd_gold_hi")
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.size = Vector2(MENU.size.x, 44)
	_prompt.custom_minimum_size = Vector2(MENU.size.x, 44)
	_menu_root.add_child(_prompt)
	_choice_scroll = ScrollContainer.new()
	_choice_scroll.name = "ChoicesScroll"
	_choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_choice_scroll.follow_focus = true
	_menu_root.add_child(_choice_scroll)
	_menu = VBoxContainer.new()
	_menu.name = "Choices"
	_menu.add_theme_constant_override(&"separation", 8)
	_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choice_scroll.add_child(_menu)
	_tail = HBoxContainer.new()
	_tail.name = "Tail"
	_tail.alignment = BoxContainer.ALIGNMENT_CENTER
	_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tail)
	_btn_later = Button.new()
	_btn_later.name = "BtnLater"
	_btn_later.set_meta("reply_id", "later")
	HdTheme.apply_button(_btn_later, "ghost")
	_btn_later.custom_minimum_size = Vector2(170, 40)
	_btn_later.focus_mode = Control.FOCUS_NONE
	_btn_later.pressed.connect(func() -> void: _close({}))
	_tail.add_child(_btn_later)


## 有选项时文书和右边的选项栏一样高、一起竖向居中（短正文不剩一大块空白），最矮 DOC_MIN_H
func _layout_columns(menu_h: float) -> void:
	var h := clampf(menu_h, DOC_MIN_H, DOC.size.y)
	var top := (720.0 - h) * 0.5
	_doc.custom_minimum_size = Vector2(DOC.size.x, h)
	_doc.size = Vector2(DOC.size.x, h)
	_doc.position = Vector2(DOC.position.x, top)
	var off := top + maxf(0.0, (h - menu_h) * 0.5)
	_prompt.position = Vector2(MENU.position.x, off)
	_choice_scroll.position = Vector2(MENU.position.x, off + _prompt.size.y + 14.0)
	var choices_h := minf(_menu.get_combined_minimum_size().y, h - _prompt.size.y - 14.0 - 18.0 - 44.0)
	_choice_scroll.size = Vector2(MENU.size.x, choices_h)
	_tail.position = Vector2(MENU.position.x, _choice_scroll.position.y + choices_h + 18.0)
	_tail.size = Vector2(MENU.size.x, 44)


func _place_tail_read() -> void:
	HdTheme.apply_button(_btn_later, "secondary")
	_btn_later.custom_minimum_size = Vector2(180, 42)
	_tail.position = Vector2(DOC_READ.position.x, DOC_READ.end.y + 16)
	_tail.size = Vector2(DOC_READ.size.x, 44)
