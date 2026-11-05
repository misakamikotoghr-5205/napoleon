# 当票：登记（当号、日期、当户、当物、成色、当本、到期）→ 填当票（一式两份）→ 盖“德厚当记”→ 交钱收物。
# 成色栏永远有“如实写”和“照老规矩写破旧”两个选项（设计稿第二天清晨）。
extends PanelContainer

signal finished(condition)

var draft: Dictionary = {}
var condition: String = ""
var stamped: bool = false
var stage: int = 0
var paper: TextureRect
var ink: Control
var stamp_rect: TextureRect
var rows_lbl: RichTextLabel
var cond_box: HBoxContainer
var stamp_btn: Button
var give_btn: Button
var stage_lbl: Label
var stamp_anim: float = 0.0
var is_practice: bool = false

func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.box(Color("#2a1f17"), Color("#5a3f2a"), 4, 2, 14))
	var h := UiStyle.hbox(18)
	add_child(h)
	paper = TextureRect.new()
	paper.texture = DB.tex("art/ui/ticket_blank.png")
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.custom_minimum_size = Vector2(288, 384)
	paper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(paper)
	ink = Control.new()
	ink.set_anchors_preset(Control.PRESET_FULL_RECT)
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ink.draw.connect(_draw_paper)
	paper.add_child(ink)
	stamp_rect = TextureRect.new()
	stamp_rect.texture = DB.tex("art/ui/stamp.png")
	stamp_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stamp_rect.stretch_mode = TextureRect.STRETCH_SCALE
	stamp_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stamp_rect.size = Vector2(72, 72)
	stamp_rect.pivot_offset = Vector2(36, 36)
	stamp_rect.position = Vector2(56, 250)
	stamp_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp_rect.visible = false
	paper.add_child(stamp_rect)
	var v := UiStyle.vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UiStyle.title_label("开当票", 30, UiStyle.LAMP))
	stage_lbl = UiStyle.label("", 15, UiStyle.MIST)
	v.add_child(stage_lbl)
	rows_lbl = RichTextLabel.new()
	rows_lbl.bbcode_enabled = true
	rows_lbl.fit_content = true
	rows_lbl.add_theme_font_size_override("normal_font_size", 17)
	rows_lbl.add_theme_color_override("default_color", UiStyle.PAPER)
	v.add_child(rows_lbl)
	v.add_child(UiStyle.label("成色一栏怎么写？", 17, UiStyle.LAMP_PALE))
	cond_box = UiStyle.hbox(8)
	v.add_child(cond_box)
	stamp_btn = UiStyle.button("盖章：德厚当记", 18, "seal")
	stamp_btn.pressed.connect(_stamp)
	v.add_child(stamp_btn)
	give_btn = UiStyle.button("交钱、收物（客人拿走一份）", 18)
	give_btn.pressed.connect(_give)
	v.add_child(give_btn)

func open(p_draft: Dictionary, practice: bool) -> void:
	draft = p_draft
	is_practice = practice
	condition = ""
	stamped = false
	stamp_anim = 0.0
	stamp_rect.visible = false
	visible = true
	var t := ""
	t += "当号：[b]%s[/b]\n日期：%s\n当户：%s\n当物：%s%s\n当本：%d 蚨（%s）\n月息：三分　当期：三十天\n到期：%s" % [draft["no"], draft["date"], draft["borrower"], draft["item"],
		("　重 %s" % draft["weight"]) if str(draft.get("weight", "")) != "" else "", int(draft["principal"]), UiStyle.cn_money(int(draft["principal"])), draft["due"]]
	if practice:
		t += "\n[color=#9aa4aa]（练习：不动用钱匣）[/color]"
	rows_lbl.text = t
	for c in cond_box.get_children():
		cond_box.remove_child(c)
		c.queue_free()
	for o in draft["condition_options"]:
		var b := UiStyle.button(("如实写：" if o["id"] == "true" else "照老规矩写：") + str(o["text"]), 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = o["id"]
		b.pressed.connect(choose.bind(id))
		b.set_meta("id", id)
		cond_box.add_child(b)
	_update()

func choose(id: String) -> void:
	condition = id
	_update()

func _update() -> void:
	for b in cond_box.get_children():
		b.add_theme_stylebox_override("normal", UiStyle.box(Color("#b0262a") if b.get_meta("id") == condition else UiStyle.PAPER_OLD, UiStyle.WOOD, 2, 3, 8))
		b.add_theme_color_override("font_color", UiStyle.PAPER if b.get_meta("id") == condition else UiStyle.INK)
	stamp_btn.disabled = condition == "" or stamped
	give_btn.disabled = not stamped
	if condition == "":
		stage_lbl.text = "① 登记入账、填当票：先定成色一栏。"
	elif not stamped:
		stage_lbl.text = "② 盖章：在当票上盖“德厚当记”。"
	else:
		stage_lbl.text = "③ 收物：练习不动钱匣。" if is_practice else "③ 交钱、收物：钱从钱匣拨出，当物推进典当盒。"
	ink.queue_redraw()

func _stamp() -> void:
	if condition == "":
		return
	stamped = true
	stamp_rect.visible = true
	stamp_rect.scale = Vector2(1.6, 1.6)
	stamp_rect.modulate.a = 0.4
	var tw := create_tween().set_parallel(true)
	tw.tween_property(stamp_rect, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	tw.tween_property(stamp_rect, "modulate:a", 0.95, 0.18)
	tw.chain().tween_callback(ink.queue_redraw)
	_update()

func _process(_d: float) -> void:
	if stamp_anim > 0.0:
		ink.queue_redraw()

func _give() -> void:
	if not stamped:
		return
	visible = false
	emit_signal("finished", condition)

func _cond_text() -> String:
	for o in draft.get("condition_options", []):
		if o["id"] == condition:
			return str(o["text"])
	return ""

func _draw_paper() -> void:
	var f := UiStyle.body_font()
	# 竖排书写：从右往左，写在表头下面的格子里
	var cols: Array = [
		str(draft.get("no", "")),
		"当户 " + str(draft.get("borrower", "")),
		"当物 " + str(draft.get("item", "")),
		"成色 " + (_cond_text() if condition != "" else "＿＿"),
		"当本 " + UiStyle.cn_money(int(draft.get("principal", 0))) + "蚨",
		"月息三分 当期三十天",
	]
	var x := ink.size.x - 34.0
	for i in range(cols.size()):
		var col: String = cols[i]
		var y := 84.0
		var size := 14
		for ch in col:
			if y > ink.size.y - 24:
				break
			if ch == " ":
				y += 6
				continue
			ink.draw_string(f, Vector2(x - 11, y), ch, HORIZONTAL_ALIGNMENT_CENTER, 22, size, UiStyle.INK)
			y += size + 2
		x -= 40.0
	if stamped:
		ink.draw_string(UiStyle.title_font(), Vector2(52, 345), "德厚当记", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiStyle.SEAL)
