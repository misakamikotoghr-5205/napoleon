# 右侧栏：日期、钱匣（显示）、口碑（进度条）、缴费倒计时、门旗；
# 柜台会话时变成“算盘”议价面板：客人要价 / 你的出价 / 建议价 / 心里估价（第一天另显示底价）。
# 本心、维持会怀疑、势力信任、人物好感都是隐藏数值，这里不显示（GameJev UX01）。
extends PanelContainer

signal offer(value)
signal extra(id)
signal deal(id)
signal refuse
signal open_inspect
signal closed

var main
var date_lbl: Label
var cash_lbl: Label
var koubei_bar: ProgressBar
var koubei_lbl: Label
var countdown_lbl: Label
var flag_lbl: Label
var price_lbl: Label
var info_scroll: ScrollContainer
var abacus_row: HBoxContainer
var bargain_scroll: ScrollContainer
var info_box: VBoxContainer
var bargain_box: VBoxContainer
var session = null
var abacus_value: int = 0
var abacus_digits: Array = []
var abacus_bead_btns: Array = []
var abacus_lbl: Label
var quote_lbl: Label
var ask_lbl: Label
var sug_lbl: Label
var est_lbl: Label
var floor_lbl: Label
var npc_lbl: Label
var hint_lbl: Label
var extras_box: VBoxContainer
var offer_btn: Button
var fund_btn: Button
var accept_btn: Button
var refuse_btn: Button
var practice_mode: bool = false
var has_deals: bool = false   # 会话自带“拒收”类特殊成交时，不再显示通用的“推回去”
var enabled: bool = true
var close_btn: Button

func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.box(Color("#2a1f17ee"), Color("#5a3f2a"), 4, 2, 12))
	var v := UiStyle.vbox(3)
	add_child(v)
	# v0.3b：侧栏按需弹出，顶部可关
	var top := UiStyle.hbox(6)
	v.add_child(top)
	var title := UiStyle.label("柜台匣", 16, UiStyle.LAMP, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	close_btn = UiStyle.button("合上 ✕", 13, "wood")
	close_btn.tooltip_text = "收起侧栏（议价中请先了结本笔，或点「不收了」）"
	close_btn.pressed.connect(_on_close_pressed)
	top.add_child(close_btn)
	# v0.3：日期即万年历入口（点开看）
	date_lbl = UiStyle.label("", 17, UiStyle.LAMP_PALE)
	date_lbl.add_theme_font_override("font", UiStyle.title_font())
	date_lbl.add_theme_font_size_override("font_size", 19)
	date_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	date_lbl.tooltip_text = "点开万年历"
	date_lbl.gui_input.connect(_on_date_input)
	v.add_child(date_lbl)
	var row := UiStyle.hbox(8)
	v.add_child(row)
	row.add_child(UiStyle.label("钱匣", 16, UiStyle.MIST, false))
	cash_lbl = UiStyle.label("600 蚨", 20, UiStyle.LAMP, false)
	row.add_child(cash_lbl)
	var row2 := UiStyle.hbox(8)
	v.add_child(row2)
	row2.add_child(UiStyle.label("口碑", 16, UiStyle.MIST, false))
	koubei_bar = ProgressBar.new()
	koubei_bar.min_value = 0
	koubei_bar.max_value = 100
	koubei_bar.show_percentage = false
	koubei_bar.custom_minimum_size = Vector2(150, 14)
	koubei_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	koubei_bar.add_theme_stylebox_override("background", UiStyle.box(Color("#1f1712"), Color("#5a3f2a"), 1, 1, 0))
	koubei_bar.add_theme_stylebox_override("fill", UiStyle.box(Color("#c99a5e"), Color("#c99a5e"), 0, 1, 0))
	row2.add_child(koubei_bar)
	koubei_lbl = UiStyle.label("50", 15, UiStyle.LAMP_PALE, false)
	row2.add_child(koubei_lbl)
	countdown_lbl = UiStyle.label("", 15, Color("#e06a50"), false)
	v.add_child(countdown_lbl)
	flag_lbl = UiStyle.label("", 15, UiStyle.PAPER_OLD)
	v.add_child(flag_lbl)
	price_lbl = UiStyle.label("", 15, UiStyle.LAMP_PALE)
	price_lbl.tooltip_text = "米价、药价每天跟着世道走（米船、收药……），不看你做了什么。"
	price_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(price_lbl)
	v.add_child(UiStyle.hsep())
	info_box = UiStyle.vbox(4)
	info_scroll = UiStyle.scroll(info_box)
	info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(info_scroll)
	_build_bargain()
	bargain_scroll = UiStyle.scroll(bargain_box)
	bargain_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(bargain_scroll)
	bargain_scroll.visible = false

func _build_bargain() -> void:
	bargain_box = UiStyle.vbox(2)
	bargain_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	npc_lbl = UiStyle.label("", 17, UiStyle.LAMP)
	bargain_box.add_child(npc_lbl)
	ask_lbl = UiStyle.label("", 16, UiStyle.PAPER)
	bargain_box.add_child(ask_lbl)
	floor_lbl = UiStyle.label("", 14, Color("#e0a070"))
	bargain_box.add_child(floor_lbl)
	sug_lbl = UiStyle.label("", 14, UiStyle.LAMP_PALE)
	bargain_box.add_child(sug_lbl)
	est_lbl = UiStyle.label("", 14, UiStyle.MIST)
	bargain_box.add_child(est_lbl)
	# v0.3：模拟算盘——四档档位，上档梁珠（5）+ 下档地珠（1×4），点珠加减
	bargain_box.add_child(UiStyle.label("算盘（点珠改价 · 嘴说报价）", 12, UiStyle.MIST, false))
	var ab := UiStyle.hbox(6)
	abacus_row = ab
	ab.alignment = BoxContainer.ALIGNMENT_CENTER
	bargain_box.add_child(ab)
	abacus_digits.clear()
	abacus_bead_btns.clear()
	for i in range(4):
		var col := UiStyle.vbox(1)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var unit: int = int(pow(10, 3 - i))
		var unit_name: String = ["千", "百", "十", "个"][i]
		# 梁珠（5）
		var heaven := UiStyle.button("○", 11, "wood")
		heaven.custom_minimum_size = Vector2(40, 20)
		heaven.tooltip_text = "%s位 · 梁珠 +5 / -5" % unit_name
		heaven.pressed.connect(_bump_bead.bind(unit * 5, i, true))
		col.add_child(heaven)
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(40, 2)
		bar.color = Color("#c99a5e")
		col.add_child(bar)
		# 地珠显示
		var d := UiStyle.label("〇", 16, UiStyle.LAMP, false)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.custom_minimum_size = Vector2(40, 22)
		d.tooltip_text = unit_name
		col.add_child(d)
		var earth_row := UiStyle.hbox(1)
		earth_row.alignment = BoxContainer.ALIGNMENT_CENTER
		var ep := UiStyle.button("+", 11, "seal")
		ep.custom_minimum_size = Vector2(18, 18)
		ep.tooltip_text = "%s +1" % unit_name
		ep.pressed.connect(_bump.bind(unit))
		var em := UiStyle.button("−", 11, "wood")
		em.custom_minimum_size = Vector2(18, 18)
		em.tooltip_text = "%s −1" % unit_name
		em.pressed.connect(_bump.bind(-unit))
		earth_row.add_child(em)
		earth_row.add_child(ep)
		col.add_child(earth_row)
		ab.add_child(col)
		abacus_digits.append(d)
		abacus_bead_btns.append(heaven)
	abacus_lbl = UiStyle.label("你出：0 蚨", 15, UiStyle.PAPER)
	abacus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bargain_box.add_child(abacus_lbl)
	quote_lbl = UiStyle.label("", 13, UiStyle.LAMP_PALE)
	quote_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bargain_box.add_child(quote_lbl)
	var tut := UiStyle.button("口述报价教程", 12, "paper")
	tut.pressed.connect(_show_quote_tutorial)
	bargain_box.add_child(tut)
	var r := UiStyle.hbox(4)
	bargain_box.add_child(r)
	offer_btn = UiStyle.button("出价", 17, "seal")
	offer_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offer_btn.pressed.connect(_on_offer_btn)
	r.add_child(offer_btn)
	accept_btn = UiStyle.button("照他的价", 15)
	accept_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accept_btn.pressed.connect(_on_accept_btn)
	r.add_child(accept_btn)
	fund_btn = UiStyle.button("资助：多给他一些", 15, "wood")
	fund_btn.pressed.connect(_on_fund_btn)
	bargain_box.add_child(fund_btn)
	hint_lbl = UiStyle.label("", 14, UiStyle.MIST)
	bargain_box.add_child(hint_lbl)
	extras_box = UiStyle.vbox(3)
	bargain_box.add_child(extras_box)
	refuse_btn = UiStyle.button("推回去（不收）", 15, "wood")
	refuse_btn.pressed.connect(_on_refuse_btn)
	bargain_box.add_child(refuse_btn)

func _on_offer_btn() -> void:
	if enabled:
		emit_signal("offer", abacus_value)

func _on_accept_btn() -> void:
	if enabled and session != null:
		set_value(session.ask)
		emit_signal("offer", session.ask)

func _on_fund_btn() -> void:
	if enabled and session != null:
		set_value(maxi(40, int(session.suggestion * 1.6)))

func _on_refuse_btn() -> void:
	if enabled:
		emit_signal("refuse")

func _on_extra_btn(id: String) -> void:
	if enabled:
		emit_signal("extra", id)

func _on_deal_btn(id: String) -> void:
	if enabled:
		emit_signal("deal", id)

func _bump(d: int) -> void:
	set_value(clampi(abacus_value + d, 0, 9999))
	if main != null and main.beeper != null:
		main.beeper.click()

func set_value(v: int) -> void:
	abacus_value = clampi(v, 0, 9999)
	var s := "%04d" % abacus_value
	for i in range(4):
		var digit := int(s[i])
		# 梁珠亮 = 数字 >= 5；地珠数 = digit % 5
		var earth := digit % 5
		var heaven_on := digit >= 5
		abacus_digits[i].text = ("●" if heaven_on else "○") + " " + _beads(earth, 4)
		if i < abacus_bead_btns.size():
			abacus_bead_btns[i].text = "●" if heaven_on else "○"
	var prefix := "你要价" if (session != null and session.mode == "sell") else "你出"
	abacus_lbl.text = "%s：%d 蚨" % [prefix, abacus_value]
	if quote_lbl != null:
		quote_lbl.text = "嘴说：「%s」" % _oral_quote(abacus_value)

func refresh(world) -> void:
	date_lbl.text = ("%s · %s" % [world.date_text(), world.slot_name()]).replace("民国二十七年 ", "") if world.day > 0 else world.date_text().replace("民国二十七年 ", "")
	cash_lbl.text = "%d 蚨" % world.cash()
	koubei_bar.value = world.koubei
	koubei_lbl.text = str(world.koubei)
	countdown_lbl.text = world.countdown_text()
	var flabel := "不挂"
	for f in DB.get_db().factions.get("door_flags", []):
		if f["id"] == world.door_flag:
			flabel = f["label"]
	var slabel := ""
	for sg in DB.get_db().factions.get("signs", []):
		if sg["id"] == world.sign_board:
			slabel = sg["label"]
	price_lbl.text = world.price_board() if world.day > 0 else ""
	flag_lbl.text = "门旗：%s　招牌：%s" % [flabel, slabel] if world.unlocked.get("door_flag", false) else ""
	if session != null:
		refresh_session()
	else:
		_refresh_info(world)

func _refresh_info(world) -> void:
	# v0.3：去掉全局「待办」「提示」刷屏；日历点日期看，提示贴在物品旁
	for c in info_box.get_children():
		info_box.remove_child(c)
		c.queue_free()
	info_box.add_child(UiStyle.label("万年历", 16, UiStyle.LAMP_PALE, false))
	info_box.add_child(UiStyle.label("点上方日期可打开。到期事写在历上。", 13, UiStyle.MIST))
	info_box.add_child(UiStyle.hsep())
	info_box.add_child(UiStyle.label("人脉（看得见的）", 16, UiStyle.LAMP_PALE, false))
	var shown := 0
	for nid in world.npcs:
		var n: Dictionary = world.npcs[nid]
		var fav: float = float(n.get("rel", {}).get("player", {}).get("affection", 0.0))
		var roles: Array = n.get("def", {}).get("roles", [])
		if absf(fav) < 0.05 and roles.is_empty():
			continue
		var tag := (" · " + _join_roles(roles)) if not roles.is_empty() else ""
		var face := "熟" if fav > 0.15 else ("冷" if fav < -0.1 else "平")
		info_box.add_child(UiStyle.label("· %s（%s）%s" % [n.get("label", nid), face, tag], 13, UiStyle.PAPER_OLD))
		shown += 1
		if shown >= 6:
			break
	if shown == 0:
		info_box.add_child(UiStyle.label("· （还没跟谁真正打过交道）", 13, UiStyle.MIST))
	info_box.add_child(UiStyle.hsep())
	info_box.add_child(UiStyle.label("柜台：账簿 · 档案 · 鉴别录 · 算盘", 13, UiStyle.MIST))
	info_box.add_child(UiStyle.label("（情境提示会在物品旁发光后消失）", 12, UiStyle.MIST))

func open_session(s, extras: Array, deals: Array, can_act: bool) -> void:
	session = s
	practice_mode = false
	info_scroll.visible = false
	bargain_scroll.visible = true
	enabled = can_act
	has_deals = not deals.is_empty()
	if s.mode == "sell" and abacus_value == 0:
		# [shop-only] 只守铺子：算盘先拨到客人自己报的价，不拨市价合计（架上买来的假货不在算盘上露底）
		var shop_only: bool = main != null and main.director != null and main.director.shop_only()
		set_value(s.ask if shop_only else s.suggestion)
	refresh_session()
	for c in extras_box.get_children():
		extras_box.remove_child(c)
		c.queue_free()
	for e in []:
		var b := UiStyle.button("◇ " + str(e["label"]), 15, "paper", true)
		var id: String = str(e["id"])
		b.pressed.connect(_on_extra_btn.bind(id))
		b.set_meta("id", "extra:" + id)
		extras_box.add_child(b)
	for d in []:
		var b2 := UiStyle.button("◆ " + str(d["label"]), 15, "wood", true)
		var id2: String = str(d["id"])
		b2.pressed.connect(_on_deal_btn.bind(id2))
		b2.set_meta("id", "deal:" + id2)
		extras_box.add_child(b2)

func open_practice() -> void:
	session = null
	practice_mode = true
	abacus_row.visible = true
	abacus_lbl.visible = true
	offer_btn.visible = true
	info_scroll.visible = false
	bargain_scroll.visible = true
	enabled = true
	npc_lbl.text = "算盘（练习）"
	ask_lbl.text = "拨一拨珠子，随便出个数，再按“出价”。"
	floor_lbl.text = ""
	sug_lbl.text = ""
	est_lbl.text = ""
	hint_lbl.text = ""
	accept_btn.visible = false
	fund_btn.visible = false
	refuse_btn.visible = false
	for c in extras_box.get_children():
		extras_box.remove_child(c)
		c.queue_free()

func refresh_session() -> void:
	var s = session
	if s == null:
		return
	var db = main.db if main != null else DB.get_db()      # 小镇：生成的客人在这一局的 db 里
	var lab: Dictionary = s.def.get("labels", {})      # [shop-only] 保护费讲价等非收货的议价，自带一套字眼
	npc_lbl.text = "%s · %s" % [db.npc_label(s.npc_id), str(lab.get("mode", {"buy": "收购", "pawn": "活当", "sell": "卖货"}.get(s.mode, "")))]
	var bro: bool = main != null and main.director != null and main.director.brother
	if s.mode == "sell":
		ask_lbl.text = "客人出价：%d 蚨" % s.ask
		sug_lbl.text = ("哥哥小声：市价合计约 %d 蚨" % s.suggestion) if bro else ""
		if bro and main.director.shop_only():
			sug_lbl.text = "哥哥小声：先听他报价，再往上谈。"      # [shop-only] 不报市价（架上买来的假货不在这里露底）
		accept_btn.text = "按他的价卖"
	else:
		ask_lbl.text = "%s：%d 蚨" % [str(lab.get("ask", "客人要价")), s.ask]
		# 只有哥哥在旁边教的时候，才有“建议价”这种提示；真实的讨价还价不给底价、不给心里估价（R2 试玩：保留悬念）
		if bro and s.suggestion > 0:
			sug_lbl.text = "哥哥小声：%s约 %d 蚨" % ["当本" if s.mode == "pawn" else "收", s.suggestion]
		else:
			sug_lbl.text = ""
		accept_btn.text = "照他的价"
	floor_lbl.text = ""
	est_lbl.text = ""
	if s.closed:
		npc_lbl.text += "（已了结）"
		ask_lbl.text = {"accept": "成交：%d 蚨" % s.price}.get(s.result, "这笔没做成。")
		sug_lbl.text = ""
	hint_lbl.text = s.hint if bro else ""
	if s.needs_more_inspection():
		if s.min_inspect > 0 and s.inspected_total() < s.min_inspect:
			hint_lbl.text = "（先用放大镜多看几处：%d / %d）" % [s.inspected_total(), s.min_inspect]
		else:
			hint_lbl.text = "（哥哥：先别急，还有该看的地方没看。）" if bro else "（还有该看的地方没看。）"
	fund_btn.visible = s.fund_button and not s.closed
	accept_btn.visible = not s.closed
	offer_btn.visible = not s.closed
	abacus_row.visible = not s.closed
	abacus_lbl.visible = not s.closed
	# v0.2：任何时候都留一个“不做了”的出口（以前有特殊成交时会被藏起来，导致卡在还价里）
	refuse_btn.visible = not s.closed
	refuse_btn.text = str(lab.get("refuse", "不卖了，请回" if s.mode == "sell" else "不收了，推回去"))      # [shop-only]
	set_value(abacus_value)

func close_session(world) -> void:
	session = null
	practice_mode = false
	bargain_scroll.visible = false
	info_scroll.visible = true
	abacus_value = 0
	set_value(0)
	refresh(world)

func extra_button(id: String) -> Button:
	for b in extras_box.get_children():
		if b.get_meta("id", "") == id:
			return b
	return null

func _on_close_pressed() -> void:
	emit_signal("closed")

func _on_date_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if main != null and main.has_method("_open_calendar"):
			main._open_calendar()

func _bump_bead(delta: int, _rod: int, _heaven: bool) -> void:
	# 梁珠：若该位已含 5 则减 5，否则加 5
	var s := "%04d" % abacus_value
	var digit := int(s[_rod])
	if digit >= 5:
		set_value(abacus_value - int(pow(10, 3 - _rod)) * 5)
	else:
		set_value(abacus_value + int(pow(10, 3 - _rod)) * 5)
	if main != null and main.beeper != null:
		main.beeper.click()

func focus_abacus() -> void:
	if bargain_scroll != null:
		bargain_scroll.visible = true
	if abacus_row != null:
		abacus_row.modulate = Color(1.2, 1.1, 0.8)
		var tw := create_tween()
		tw.tween_property(abacus_row, "modulate", Color.WHITE, 0.8)

func _oral_quote(v: int) -> String:
	# 口述报价：把数字念成银钱口头语
	if v <= 0:
		return "一个子儿不给"
	var parts: Array = []
	var qian := int(v / 1000)
	var bai := int((v % 1000) / 100)
	var shi := int((v % 100) / 10)
	var ge := v % 10
	if qian > 0:
		parts.append("%s千" % _digit_cn(qian))
	if bai > 0:
		parts.append("%s百" % _digit_cn(bai))
	elif qian > 0 and (shi > 0 or ge > 0):
		parts.append("零")
	if shi > 0:
		parts.append(("十" if shi == 1 and qian == 0 and bai == 0 else _digit_cn(shi) + "十"))
	elif (qian > 0 or bai > 0) and ge > 0 and "零" not in parts:
		parts.append("零")
	if ge > 0:
		parts.append(_digit_cn(ge))
	return _join_parts(parts) + "蚨"

func _digit_cn(d: int) -> String:
	return ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"][clampi(d, 0, 9)]

func _show_quote_tutorial() -> void:
	hint_lbl.text = "教程：拨珠得数 → 嘴里报「%s」→ 再按出价。客人听的是价，不是珠。" % _oral_quote(abacus_value if abacus_value > 0 else 36)
	if main != null:
		main._toast("口述报价：拨盘后照着「嘴说」念给客人听")

func _join_parts(parts: Array) -> String:
	var out := ""
	for p in parts:
		out += str(p)
	return out

func _beads(on: int, total: int) -> String:
	var out := ""
	for k in range(total):
		out += "●" if k < on else "○"
	return out

func _join_roles(roles: Array) -> String:
	var out := ""
	for i in range(roles.size()):
		if i > 0:
			out += "、"
		out += str(roles[i])
	return out
