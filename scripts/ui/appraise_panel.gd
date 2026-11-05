# 验货：对着图鉴找不同，用朱笔把不对的地方圈出来。
#   左页：图鉴——真品该有的样子（大图）+ 真品特征 / 允许的差异 / 常见破绽；手边没有这一类的页，只给几条常识。
#   右页：手上这件（像素 ×5）。先选工具，按住鼠标绕着要看的地方画一圈，松手按圈判：
#     圈中、工具也对 → session.inspect(iid, pid) 揭开这一处（写进档案簿），圈旁钉一张编号批注；
#     圈空了 → “这里看不出和图鉴有什么不同”；圈得太大不算数。
#   每件三笔墨（有这一类的鉴别录多一笔），一笔两分钟（小镇里走钟）；“再验一次”时原来的圈都还在，墨不退。
#   细处（放大镜的部位）只有拿起放大镜、在镜片里才看得出；镜片同时罩在图鉴的同一处，方便对照。
#   秤：显示秤上的分量，和图鉴上的分量对照。手摸、鼻闻：圈那一处，给一句手感 / 气味。
# 自动试玩、测试：circle_at(手上这件画面里的局部坐标, 半径, 工具) 画一个真圈，走和鼠标同一条路。
extends PanelContainer

const Appraise = preload("res://scripts/core/appraise.gd")
const FlawRender = preload("res://scripts/core/flaw_render.gd")

signal closed
signal inspected(iid, pid)
signal done_practice

const IMG := 64.0
const HAND_SCALE := 5.0
const REF_SCALE := 4.0
const LENS_R := 60.0
const LENS_ZOOM := 2.0
const INK_RED := Color("#c3352a")
const NUMS := ["①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩"]
const TONE_COLOR := {"tell": "#b0262a", "benign": "#8a5a1e", "plain": "#1f1712", "miss": "#6e6458"}

var main
var session = null
var iid: String = ""
var practice: bool = false
var tool: String = "hand"
var atlas_open: bool = false      # 图鉴翻开了没有（翻开一次，之后一直开着）
var ref: Dictionary = {}
var last_text: String = ""
var last_tone: String = ""
var last_kind: String = ""

var _ref_img: Image
var _hand_soft: Image
var _hand_sharp: Image
var _tex_ref: ImageTexture
var _tex_soft: ImageTexture
var _tex_sharp: ImageTexture
var _stroke: PackedVector2Array = PackedVector2Array()
var _drawing: bool = false
var _lens: Vector2 = Vector2(-1, -1)    # 镜片中心（物品图坐标 0..64）；负数 = 没有
var _pulse: float = 0.0
var _slip: int = -1                     # 正在看哪一张批注（鼠标停在圈旁的编号上，或刚圈完的那张）

var tabs_box: HBoxContainer
var coach_box: PanelContainer
var coach_lbl: Label
var name_lbl: Label
var info_lbl: Label
var ref_title: Label
var ref_canvas: Control
var ref_cover: Button
var ref_locked: Label
var ref_notes: RichTextLabel
var hand_canvas: Control
var ink_canvas: Control
var ink_lbl: Label
var status_lbl: RichTextLabel
var notes: RichTextLabel
var opts_box: VBoxContainer
var tools_box: HBoxContainer
var close_btn: Button
var tool_btns: Dictionary = {}

func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.box(Color("#f4e2b0"), Color("#3a2a1e"), 5, 3, 12))
	var root := UiStyle.vbox(6)
	add_child(root)
	var head := UiStyle.hbox(10)
	root.add_child(head)
	name_lbl = UiStyle.title_label("", 26)
	head.add_child(name_lbl)
	info_lbl = UiStyle.label("", 15, UiStyle.INK_SOFT, false)
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(info_lbl)
	tabs_box = UiStyle.hbox(4)
	head.add_child(tabs_box)
	coach_box = PanelContainer.new()
	coach_box.add_theme_stylebox_override("panel", UiStyle.box(Color(0.12, 0.09, 0.07, 0.94), UiStyle.LAMP, 2, 3, 8))
	coach_lbl = UiStyle.label("", 16, UiStyle.LAMP_PALE)
	coach_box.add_child(coach_lbl)
	coach_box.visible = false
	root.add_child(coach_box)
	var body := UiStyle.hbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	# ---- 左页：图鉴 ----
	var left := UiStyle.vbox(4)
	left.custom_minimum_size = Vector2(264, 0)
	body.add_child(left)
	ref_title = UiStyle.label("图鉴", 16, UiStyle.INK, false)
	left.add_child(ref_title)
	ref_canvas = Control.new()
	ref_canvas.custom_minimum_size = Vector2(IMG * REF_SCALE, IMG * REF_SCALE)
	ref_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ref_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	ref_canvas.draw.connect(_draw_ref)
	ref_canvas.gui_input.connect(_ref_input)
	ref_canvas.mouse_exited.connect(_lens_off)
	left.add_child(ref_canvas)
	ref_cover = UiStyle.button("翻开图鉴\n对照真品", 20, "wood", true)
	ref_cover.position = Vector2(48, 88)
	ref_cover.size = Vector2(160, 80)
	ref_cover.pressed.connect(open_atlas)
	ref_canvas.add_child(ref_cover)
	ref_locked = UiStyle.label("没有这一类的图鉴页", 18, UiStyle.PAPER, true)
	ref_locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ref_locked.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ref_locked.position = Vector2(16, 96)
	ref_locked.size = Vector2(224, 64)
	ref_locked.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ref_canvas.add_child(ref_locked)
	ref_notes = _rich(13)
	ref_notes.custom_minimum_size = Vector2(264, 120)
	ref_notes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(ref_notes)
	# ---- 右边：手上这件 + 批注；底下一排工具 ----
	var rightside := UiStyle.vbox(6)
	rightside.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(rightside)
	var cols := UiStyle.hbox(12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rightside.add_child(cols)
	var mid := UiStyle.vbox(4)
	cols.add_child(mid)
	var mh := UiStyle.hbox(8)
	mid.add_child(mh)
	var hl := UiStyle.label("手上这件", 16, UiStyle.INK, false)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mh.add_child(hl)
	ink_lbl = UiStyle.label("墨", 15, UiStyle.INK_SOFT, false)
	mh.add_child(ink_lbl)
	ink_canvas = Control.new()
	ink_canvas.custom_minimum_size = Vector2(76, 20)
	ink_canvas.draw.connect(_draw_ink)
	mh.add_child(ink_canvas)
	hand_canvas = Control.new()
	hand_canvas.custom_minimum_size = Vector2(IMG * HAND_SCALE, IMG * HAND_SCALE)
	hand_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hand_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	hand_canvas.mouse_default_cursor_shape = Control.CURSOR_CROSS
	hand_canvas.draw.connect(_draw_hand)
	hand_canvas.gui_input.connect(_hand_input)
	hand_canvas.mouse_exited.connect(_lens_off)
	mid.add_child(hand_canvas)
	status_lbl = _rich(14)
	status_lbl.custom_minimum_size = Vector2(IMG * HAND_SCALE, 44)
	status_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(status_lbl)
	var right := UiStyle.vbox(4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(UiStyle.label("批注", 16, UiStyle.INK, false))
	notes = _rich(14)
	notes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notes.custom_minimum_size = Vector2(0, 160)
	right.add_child(notes)
	opts_box = UiStyle.vbox(2)
	right.add_child(opts_box)
	close_btn = UiStyle.button("放下（回柜台看货）", 17, "wood")
	close_btn.pressed.connect(_on_close)
	right.add_child(close_btn)
	tools_box = UiStyle.hbox(4)
	rightside.add_child(tools_box)

func _rich(fs: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = false
	r.scroll_active = true
	r.add_theme_font_size_override("normal_font_size", fs)
	r.add_theme_font_size_override("bold_font_size", fs)
	r.add_theme_color_override("default_color", UiStyle.INK)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r

func _world():
	return session.world if session != null else null

# ====================================================================
func open(s, first_iid: String = "", is_practice: bool = false) -> void:
	session = s
	practice = is_practice
	iid = first_iid if first_iid != "" else (s.item_ids[0] if not s.item_ids.is_empty() else "")
	visible = true
	_drawing = false
	_stroke = PackedVector2Array()
	_lens = Vector2(-1, -1)
	_slip = -1
	# 柜台教程留下的“点这里”小提示别盖在验货上
	if main != null and main.get("_glow_lbl") != null:
		main._glow_lbl.visible = false
	if not _usable(tool):
		tool = "hand"
	_load_item()
	_rebuild()

func _load_item() -> void:
	last_text = ""
	last_tone = ""
	last_kind = ""
	if session == null or iid == "" or not _world().ledger.items.has(iid):
		ref = {}
		return
	var it: Dictionary = session.item(iid)
	ref = Appraise.ref_entry(_world(), it)
	_ref_img = FlawRender.load_sprite(str(ref.get("sprite", "")))
	if _ref_img == null:
		_ref_img = FlawRender.base_image(it)
	var seed_v: int = int(_world().world_seed)
	_hand_soft = FlawRender.hand_image(it, seed_v, false)
	_hand_sharp = FlawRender.hand_image(it, seed_v, true)
	_tex_ref = ImageTexture.create_from_image(_ref_img)
	_tex_soft = ImageTexture.create_from_image(_hand_soft)
	_tex_sharp = ImageTexture.create_from_image(_hand_sharp)

func _usable(t: String) -> bool:
	return session == null or session.can_use_tool(t)

func has_ref() -> bool:
	return bool(ref.get("unlocked", false))

func ink_left() -> int:
	return session.ink_left(iid) if session != null and iid != "" else 0

func open_atlas() -> void:
	atlas_open = true
	if main != null and main.beeper != null:
		main.beeper.click()
	_rebuild()

func set_tool(t: String) -> void:
	if not Appraise.TOOLS.has(t) or not _usable(t):
		return
	tool = t
	if main != null and main.beeper != null:
		main.beeper.click()
	_rebuild()

func _select_item(id: String) -> void:
	iid = id
	_load_item()
	_rebuild()

# ====================================================================
func _rebuild() -> void:
	if session == null:
		return
	for c in tabs_box.get_children():
		tabs_box.remove_child(c)
		c.queue_free()
	if session.item_ids.size() > 1:
		for i in session.item_ids:
			var it0: Dictionary = session.item(i)
			var b := UiStyle.button(str(it0["name"]).substr(0, 8), 13, "paper" if i != iid else "seal")
			var id: String = i
			b.pressed.connect(_select_item.bind(id))
			tabs_box.add_child(b)
	if iid == "":
		return
	var it: Dictionary = session.item(iid)
	name_lbl.text = str(it["name"])
	info_lbl.text = "类别：%s" % it.get("cat_cn", "")
	# 左页
	var opened := atlas_open and has_ref()
	ref_cover.visible = has_ref() and not atlas_open
	ref_locked.visible = not has_ref()
	ref_title.text = ("图鉴 · " + str(ref.get("title", ""))) if has_ref() else "图鉴"
	ref_notes.text = _ref_text(opened)
	# 右页
	ink_lbl.text = "墨（每笔约两分钟）" if _town_counter() else "墨"
	status_lbl.text = _status_text(it)
	notes.text = _notes_text(it)
	# 工具
	for c in tools_box.get_children():
		tools_box.remove_child(c)
		c.queue_free()
	tool_btns.clear()
	for t in Appraise.TOOLS:
		var on: bool = t == tool
		var b2 := UiStyle.button("%s·%s" % [Appraise.TOOL_CN[t], Appraise.TOOL_HINT[t]], 14, "seal" if on else "paper")
		b2.disabled = not _usable(t)
		if b2.disabled:
			b2.modulate = Color(1, 1, 1, 0.4)
			b2.tooltip_text = "还没有%s。" % {"scale": "小秤", "book": "《沈记药材鉴别录》"}.get(t, Appraise.TOOL_CN[t])
		var tid: String = t
		b2.pressed.connect(set_tool.bind(tid))
		tools_box.add_child(b2)
		tool_btns[t] = b2
	# 选项（拆开出价 / 认定假货 / 鉴别录）
	for c in opts_box.get_children():
		opts_box.remove_child(c)
		c.queue_free()
	if not practice and session.mode != "practice":
		if session.split or (session.mode == "sell" and session.item_ids.size() > 1):
			var cb := _check("这件也算进去" if session.mode != "sell" else "这件要卖", session.selected.get(iid, true), UiStyle.INK)
			cb.toggled.connect(_on_select_toggled)
			opts_box.add_child(cb)
		var fk := _check("我看这是假货", session.judged.get(iid, "") == "fake", UiStyle.SEAL)
		fk.toggled.connect(_on_fake_toggled)
		opts_box.add_child(fk)
	var w = _world()
	if main != null and w != null and w.unlocked.get("medbook", false) and str(it.get("cat", "")) == "medicine":
		var mb := UiStyle.button("翻《沈记药材鉴别录》对照", 14, "wood")
		mb.pressed.connect(main._open_medbook)
		opts_box.add_child(mb)
	if practice:
		close_btn.text = "看完了"
		close_btn.disabled = not _practice_done()
	elif not session.pending_events.is_empty():
		close_btn.text = "放下（回柜台 · 有发现）"
		close_btn.disabled = false
	else:
		close_btn.text = "放下（回柜台看货）"
		close_btn.disabled = false
	_update_coach()
	ref_canvas.queue_redraw()
	hand_canvas.queue_redraw()
	ink_canvas.queue_redraw()

func _check(text: String, on: bool, col: Color) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = text
	cb.button_pressed = on
	cb.focus_mode = Control.FOCUS_NONE
	cb.add_theme_font_size_override("font_size", 15)
	for k in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color"]:
		cb.add_theme_color_override(k, col)
	return cb

func _town_counter() -> bool:
	return main != null and main.get("town") != null and str(main.town.get("mode")) == "counter" and not practice

func _e(s: String) -> String:
	return s.replace("[", "[lb]")

func _ref_text(opened: bool) -> String:
	if not has_ref():
		var g: Array = Appraise.general_hints()
		var t := ""
		for i in g.size():
			t += ("[color=#5a3f2a]%s[/color]\n" % _e(str(g[i]))) if i == 0 else ("· %s\n" % _e(str(g[i])))
		return t
	if not opened:
		return "[color=#7b5638]（左边是图鉴。翻开它，对着真品的样子看手上这件。）[/color]"
	var out := ""
	if str(ref.get("weight", "")) != "":
		out += "[b]分量[/b]　%s\n" % _e(str(ref["weight"]))
	for sec in [["real", "真品特征", "#1f1712"], ["ok", "允许的差异", "#4a6a3a"], ["tells", "常见破绽", "#b0262a"]]:
		var rows: Array = ref.get(sec[0], [])
		var lines := ""
		for r in rows:
			if str(r) != "" and str(r) != "——":
				lines += "· %s\n" % _e(str(r))
		if lines != "":
			out += "[b][color=%s]%s[/color][/b]\n%s" % [sec[2], sec[1], lines]
	return out

func _notes_text(it: Dictionary) -> String:
	var t := ""
	var cs: Array = session.circles.get(iid, [])
	var circled: Dictionary = {}
	for i in cs.size():
		var c: Dictionary = cs[i]
		for pid in c.get("pids", []):
			circled[str(pid)] = true
		var col: String = TONE_COLOR.get(str(c.get("tone", "miss")), "#1f1712")
		t += "[color=%s]%s %s[/color]\n" % [col, NUMS[mini(i, NUMS.size() - 1)], _e(str(c.get("text", "")))]
	# 不是圈出来的（剧情里看过、早先验过的）也列上
	var extra := ""
	for p in it.get("parts", []):
		var pid := str(p["id"])
		if session.inspected.get(iid, {}).has(pid) and not circled.has(pid):
			var col2 := "#b0262a" if p.get("tell", false) else "#1f1712"
			extra += "[color=%s]· %s：%s[/color]\n" % [col2, _e(str(p["label"])), _e(str(p.get("_shown", p["text"])))]
	if extra != "":
		t += ("\n" if t != "" else "") + extra
	if t == "":
		t = "[color=#7b5638]（还没圈。客人说的不算数，圈出来的才算。）[/color]"
	return t

func _status_text(it: Dictionary) -> String:
	var t := ""
	if last_text != "":
		t += "[color=%s]%s[/color]\n" % [TONE_COLOR.get(last_tone, "#1f1712"), _e(last_text)]
	elif ink_left() <= 0:
		t += "[color=#6e6458]墨用完了。[/color]\n"
	elif tool == "magnifier":
		t += "[color=#6e6458]镜片跟着手走：细处在镜片里才看得清。按住鼠标画圈。[/color]\n"
	else:
		t += "[color=#6e6458]按住鼠标，绕着要看的地方画一圈。[/color]\n"
	var scale_part := false
	for p in it.get("parts", []):
		if str(p.get("tool", "")) == "scale":
			scale_part = true
	if tool == "scale" or it.get("weighed", false):
		var refw := str(ref.get("weight", "")) if has_ref() else ""
		if not scale_part:
			t += "秤：这件东西不论分量。"
		else:
			var mine := str(it.get("weight", "")) if it.get("weighed", false) else "（用秤圈住它称一称）"
			if it.get("weighed", false) and mine == "":
				for p in it.get("parts", []):
					if str(p.get("tool", "")) == "scale" and session.inspected.get(iid, {}).has(str(p["id"])):
						mine = str(p.get("_shown", p.get("text", "")))
			t += "秤：%s　｜　图鉴：%s" % [_e(mine), _e(refw) if refw != "" else "—"]
	# 想起别处见过的（剧情记忆，不指位置）
	for p in it.get("parts", []):
		var f := str(p.get("highlight_if", ""))
		if f != "" and _world().flags.get(f, false) and not session.inspected.get(iid, {}).has(str(p["id"])):
			t += "\n[color=#8a5a1e]%s[/color]" % _e(str(p.get("highlight_note", "")))
	return t

func _practice_done() -> bool:
	return session.inspected_total() >= 1 or ink_left() <= 0

func _update_coach() -> void:
	var it: Dictionary = session.item(iid) if iid != "" else {}
	var coach: Dictionary = it.get("coach", {}) if practice else {}
	coach_box.visible = not coach.is_empty()
	if coach.is_empty():
		return
	var key := "circle"
	var cs: Array = session.circles.get(iid, [])
	var tells_left := 0
	for p in it.get("parts", []):
		if p.get("tell", false) and not session.inspected.get(iid, {}).has(str(p["id"])):
			tells_left += 1
	if has_ref() and not atlas_open:
		key = "open"
	elif tells_left == 0 or ink_left() <= 0:
		key = "done"
	elif cs.is_empty() and tool != "magnifier":
		key = "tool"
	elif not cs.is_empty():
		key = {"hit": "hit", "tool": "tool_wrong", "miss": "miss", "oversize": "miss", "again": "miss"}.get(last_kind, "circle")
		if last_kind == "hit" and last_tone == "benign":
			key = "benign"
	coach_lbl.text = str(coach.get(key, coach.get("circle", "")))

# ====================================================================
# 画
func _draw_ink() -> void:
	if session == null or iid == "":
		return
	var mx: int = session.ink_max(iid)
	var left: int = ink_left()
	for i in mx:
		var c := Vector2(9 + i * 17, 10)
		if i < left:
			ink_canvas.draw_circle(c, 6.0, Color("#1f1712"))
			ink_canvas.draw_circle(c + Vector2(-2, -2), 1.6, Color(1, 1, 1, 0.35))
		else:
			ink_canvas.draw_arc(c, 6.0, 0, TAU, 20, Color("#7b5638"), 1.5, true)

func _draw_ref() -> void:
	var sz := ref_canvas.size
	ref_canvas.draw_rect(Rect2(Vector2.ZERO, sz), Color("#e9d6a0"))
	ref_canvas.draw_rect(Rect2(Vector2.ZERO, sz), Color("#7b5638"), false, 2.0)
	if not has_ref():
		ref_canvas.draw_rect(Rect2(Vector2(6, 6), sz - Vector2(12, 12)), Color("#5a3f2a"))
		return
	if not atlas_open:
		# 合着的图鉴：蓝布封面
		ref_canvas.draw_rect(Rect2(Vector2(6, 6), sz - Vector2(12, 12)), Color("#2f4670"))
		ref_canvas.draw_rect(Rect2(Vector2(14, 14), Vector2(36, sz.y - 28)), Color("#e9d6a0"))
		var pulse := 0.5 + 0.5 * sin(_pulse * 4.0)
		ref_canvas.draw_rect(Rect2(ref_cover.position - Vector2(4, 4), ref_cover.size + Vector2(8, 8)), Color(1.0, 0.82, 0.35, 0.4 + 0.5 * pulse), false, 3.0)
		return
	if _tex_ref != null:
		ref_canvas.draw_texture_rect(_tex_ref, Rect2(Vector2.ZERO, Vector2(IMG, IMG) * REF_SCALE), false)
	if tool == "magnifier" and _lens.x >= 0.0:
		_draw_lens(ref_canvas, _tex_ref, _lens, REF_SCALE, LENS_R * 0.85)

func _draw_hand() -> void:
	var sz := hand_canvas.size
	hand_canvas.draw_rect(Rect2(Vector2.ZERO, sz), Color("#4a3626"))
	hand_canvas.draw_rect(Rect2(Vector2.ZERO, sz), Color("#2a1f17"), false, 3.0)
	if _tex_soft != null:
		hand_canvas.draw_texture_rect(_tex_soft, Rect2(Vector2.ZERO, Vector2(IMG, IMG) * HAND_SCALE), false)
	var tags: Array = _tag_positions()
	if session != null and iid != "":
		var cs: Array = session.circles.get(iid, [])
		for i in cs.size():
			_draw_entry(cs[i], i, tags[i])
	if tool == "magnifier" and _lens.x >= 0.0 and _tex_sharp != null:
		_draw_lens(hand_canvas, _tex_sharp, _lens, HAND_SCALE, LENS_R)
	if _drawing and _stroke.size() >= 2:
		_brush(hand_canvas, _stroke, INK_RED)
	elif _slip >= 0 and _slip < tags.size():
		_draw_slip(_slip)

# 每个圈的编号签：钉在圈的右上角；挨得太近就往下挪，不叠在一起
func _tag_positions() -> Array:
	var out: Array = []
	if session == null or iid == "":
		return out
	for e in session.circles.get(iid, []):
		var cc: Array = e.get("c", [0, 0])
		var c := Vector2(float(cc[0]), float(cc[1])) * HAND_SCALE
		var r := float(e.get("r", 4.0)) * HAND_SCALE
		var tag := (c + Vector2(r * 0.72 + 9.0, -r * 0.72 - 9.0)).clamp(Vector2(11, 11), hand_canvas.size - Vector2(11, 11))
		var guard := 0
		var moved := true
		while moved and guard < 12:
			moved = false
			guard += 1
			for o in out:
				if (o as Vector2).distance_to(tag) < 22.0:
					tag = (tag + Vector2(0, 22)).clamp(Vector2(11, 11), hand_canvas.size - Vector2(11, 11))
					if tag.y >= hand_canvas.size.y - 11.0:
						tag.x -= 22.0
					moved = true
		out.append(tag)
	return out

# 圈旁钉的批注纸条：编号 + 这一笔看出来的东西
func _draw_slip(idx: int) -> void:
	var cs: Array = session.circles.get(iid, [])
	if idx >= cs.size():
		return
	var e: Dictionary = cs[idx]
	var font := UiStyle.body_font()
	var text := "%s %s" % [NUMS[mini(idx, NUMS.size() - 1)], str(e.get("text", ""))]
	var width := 190.0
	var sz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, 13)
	# 纸条钉在圈旁：上下左右四个位置里，挑一个最少盖住这些圈的
	var cc: Array = e.get("c", [0, 0])
	var c := Vector2(float(cc[0]), float(cc[1])) * HAND_SCALE
	var r := float(e.get("r", 4.0)) * HAND_SCALE
	var box := Vector2(width + 12.0, sz.y + 10.0)
	var cands: Array = [Vector2(c.x - box.x / 2.0, c.y + r + 10.0), Vector2(c.x - box.x / 2.0, c.y - r - 10.0 - box.y),
		Vector2(c.x + r + 14.0, c.y - box.y / 2.0), Vector2(c.x - r - 14.0 - box.x, c.y - box.y / 2.0)]
	var pos: Vector2 = cands[0]
	var best := INF
	for cand in cands:
		var q := (cand as Vector2).clamp(Vector2(2, 2), hand_canvas.size - box - Vector2(2, 2))
		var cover := Rect2(q, box)
		var cost := (q - (cand as Vector2)).length() * 4.0
		for o in cs:
			var oc: Array = o.get("c", [0, 0])
			var orr := float(o.get("r", 4.0)) * HAND_SCALE
			var obox := Rect2(Vector2(float(oc[0]), float(oc[1])) * HAND_SCALE - Vector2(orr, orr), Vector2(orr, orr) * 2.0)
			cost += cover.intersection(obox).get_area()
		if cost < best:
			best = cost
			pos = q
	var rect := Rect2(pos, box)
	hand_canvas.draw_rect(Rect2(rect.position + Vector2(3, 3), rect.size), Color(0, 0, 0, 0.35))
	hand_canvas.draw_rect(rect, Color("#f4e2b0"))
	hand_canvas.draw_rect(rect, Color("#7b5638"), false, 1.5)
	hand_canvas.draw_circle(rect.position + Vector2(rect.size.x / 2.0, 1.0), 2.5, INK_RED)
	var col := Color(str(TONE_COLOR.get(str(e.get("tone", "miss")), "#1f1712")))
	hand_canvas.draw_multiline_string(font, pos + Vector2(6, 16), text, HORIZONTAL_ALIGNMENT_LEFT, width, 13, -1, col)

func _draw_entry(e: Dictionary, idx: int, tag: Vector2) -> void:
	var poly := PackedVector2Array()
	for p in e.get("pts", []):
		poly.append(Vector2(float(p[0]), float(p[1])) * HAND_SCALE)
	var col := INK_RED if str(e.get("kind", "")) == "hit" else Color(INK_RED.r, INK_RED.g, INK_RED.b, 0.72)
	_brush(hand_canvas, poly, col)
	hand_canvas.draw_circle(tag, 10.0, Color("#f4e2b0"))
	hand_canvas.draw_arc(tag, 10.0, 0, TAU, 24, col, 2.0, true)
	var font := UiStyle.body_font()
	var num := str(idx + 1)
	var w := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	hand_canvas.draw_string(font, tag + Vector2(-w / 2.0, 5.5), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)

# 朱笔：一道主笔，再叠一道细的、略抖的笔，起笔处墨重一点
func _brush(ci: CanvasItem, poly: PackedVector2Array, col: Color) -> void:
	if poly.size() < 2:
		return
	ci.draw_polyline(poly, col, 4.0, true)
	var rough := PackedVector2Array()
	for k in poly.size():
		rough.append(poly[k] + Vector2(sin(k * 2.3), cos(k * 1.7)) * 1.6)
	ci.draw_polyline(rough, Color(col.r * 0.85, col.g * 0.8, col.b * 0.8, col.a * 0.6), 2.0, true)
	ci.draw_circle(poly[0], 3.0, col)
	ci.draw_circle(poly[poly.size() - 1], 1.8, col)

func _draw_lens(ci: CanvasItem, tex: Texture2D, center: Vector2, zoom_scale: float, radius: float) -> void:
	if tex == null:
		return
	var m := center * zoom_scale
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for k in 48:
		var a := TAU * k / 48.0
		var off := Vector2(cos(a), sin(a)) * radius
		pts.append(m + off)
		uvs.append((center + off / (zoom_scale * LENS_ZOOM)) / IMG)
	ci.draw_colored_polygon(pts, Color("#4a3626"))
	ci.draw_colored_polygon(pts, Color.WHITE, uvs, tex)
	ci.draw_arc(m, radius, 0, TAU, 48, Color("#3a2a1e"), 5.0, true)
	ci.draw_arc(m, radius + 3.0, 0, TAU, 48, Color("#c9a24a"), 2.0, true)
	var h0 := m + Vector2(0.7071, 0.7071) * (radius + 4.0)
	ci.draw_line(h0, h0 + Vector2(0.7071, 0.7071) * 26.0, Color("#5a3f2a"), 8.0, true)

func _process(delta: float) -> void:
	if not visible:
		return
	_pulse += delta
	if tool == "magnifier" or not atlas_open:
		ref_canvas.queue_redraw()
	if tool == "magnifier" or _drawing:
		hand_canvas.queue_redraw()

func _lens_off() -> void:
	if not _drawing:
		_lens = Vector2(-1, -1)

# ====================================================================
# 画圈
func _ref_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and atlas_open and has_ref():
		_lens = (ev.position / REF_SCALE).clamp(Vector2.ZERO, Vector2(IMG, IMG))

func _hand_input(ev: InputEvent) -> void:
	if session == null or iid == "":
		return
	if ev is InputEventMouseMotion:
		_lens = (ev.position / HAND_SCALE).clamp(Vector2.ZERO, Vector2(IMG, IMG))
		if not _drawing:
			var over := -1
			var tags: Array = _tag_positions()
			for i in tags.size():
				if (tags[i] as Vector2).distance_to(ev.position) <= 12.0:
					over = i
			if over != _slip and (over >= 0 or _slip >= 0):
				_slip = over
				hand_canvas.queue_redraw()
		if _drawing:
			if _stroke.is_empty() or _stroke[_stroke.size() - 1].distance_to(ev.position) >= 3.0:
				_stroke.append(ev.position)
			hand_canvas.queue_redraw()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_slip = -1
			if ink_left() <= 0:
				_say("墨用完了。这件东西只能看到这儿了。", "miss", "")
				return
			_drawing = true
			_stroke = PackedVector2Array([ev.position])
		elif _drawing:
			_drawing = false
			var pts := _stroke
			_stroke = PackedVector2Array()
			finish_stroke(pts)
		hand_canvas.accept_event()

func _say(text: String, tone: String, kind: String) -> void:
	last_text = text
	last_tone = tone
	last_kind = kind
	_rebuild()

# 一笔画完：拟合成圈，判中，花墨、花时间，钉批注。返回 {kind, pids, text}
func finish_stroke(pts_local: PackedVector2Array) -> Dictionary:
	if session == null or iid == "":
		return {"kind": "none"}
	var pts: Array = []
	for p in pts_local:
		pts.append(p / HAND_SCALE)
	var fit: Dictionary = Appraise.fit_circle(pts)
	if not fit["ok"]:
		var why := str(fit.get("why", ""))
		var msg := "点一下不算。按住鼠标，绕着要看的地方画个圈。" if why in ["short", "small"] else "要画个圈，把要看的地方圈在里头。"
		_say(msg, "miss", "")
		return {"kind": "invalid", "why": why}
	if ink_left() <= 0:
		_say("墨用完了。这件东西只能看到这儿了。", "miss", "")
		return {"kind": "no_ink"}
	var center: Vector2 = fit["center"]
	var radius: float = fit["radius"]
	var it: Dictionary = session.item(iid)
	var res: Dictionary = Appraise.hit_test(it, center, radius, tool, session.inspected.get(iid, {}))
	var kind := str(res["kind"])
	var text := ""
	var tone := "miss"
	var pids: Array = res.get("pids", [])
	if kind == "hit":
		var texts: Array = []
		tone = "plain"
		for pid in pids:
			var finding: String = session.inspect(iid, str(pid))
			var p: Dictionary = FlawRender.part_of(it, str(pid))
			finding = str(p.get("_shown", finding))
			var differs := has_ref() and FlawRender.region_differs(_ref_img, _hand_sharp, _rect_i(Appraise.part_rect(p)))
			var note: Dictionary = Appraise.hit_note(it, str(pid), finding, differs, has_ref())
			texts.append(note["text"])
			if note["tone"] == "tell" or (note["tone"] == "benign" and tone != "tell"):
				tone = note["tone"]
			emit_signal("inspected", iid, str(pid))
		text = "\n".join(texts)
	else:
		var look := _hand_sharp if tool == "magnifier" else _hand_soft
		var box := Rect2i(int(center.x - radius), int(center.y - radius), int(radius * 2.0) + 1, int(radius * 2.0) + 1)
		var differs2 := has_ref() and FlawRender.region_differs(_ref_img, look, box)
		text = Appraise.miss_note(kind, has_ref(), differs2, str(res.get("need", "")))
	var simple: Array = []
	var step := maxi(1, int(ceil(pts.size() / 40.0)))
	for k in range(0, pts.size(), step):
		simple.append([snappedf(pts[k].x, 0.1), snappedf(pts[k].y, 0.1)])
	if pts.size() > 1:
		simple.append([snappedf(pts[0].x, 0.1), snappedf(pts[0].y, 0.1)])
	session.add_circle(iid, {"c": [snappedf(center.x, 0.1), snappedf(center.y, 0.1)], "r": snappedf(radius, 0.1), "tool": tool,
		"kind": kind, "pids": pids, "text": text, "tone": tone, "pts": simple})
	_spend_time()
	if main != null and main.beeper != null:
		main.beeper.click()
	_slip = session.circles[iid].size() - 1
	_say(text, tone, kind)
	return {"kind": kind, "pids": pids, "text": text}

func _rect_i(r: Rect2) -> Rect2i:
	return Rect2i(int(r.position.x), int(r.position.y), int(ceil(r.size.x)), int(ceil(r.size.y)))

func _spend_time() -> void:
	if _town_counter() and main.town.has_method("spend_minutes"):
		main.town.spend_minutes(Appraise.MINUTES_PER_STROKE)

# 程序画圈（自动试玩、测试、截图）：在“手上这件”画面的局部坐标 local_pos 处、半径 radius（像素）画一圈
func circle_at(local_pos: Vector2, radius: float, with_tool: String = "") -> Dictionary:
	if with_tool != "" and with_tool != tool:
		if not _usable(with_tool):
			return {"kind": "tool_locked"}
		tool = with_tool
	var pts := PackedVector2Array()
	var n := 28
	for k in n + 2:
		var a := TAU * float(k) / float(n) - 0.6
		var wob := 1.0 + 0.05 * sin(a * 3.0 + 0.7)
		pts.append(local_pos + Vector2(cos(a), sin(a)) * radius * wob)
	return finish_stroke(pts)

# 某个部位在“手上这件”画面里的位置（局部坐标），给自动试玩找圈的地方
func part_local_rect(pid: String) -> Rect2:
	if session == null or iid == "":
		return Rect2()
	var r := Appraise.part_rect(FlawRender.part_of(session.item(iid), pid))
	return Rect2(r.position * HAND_SCALE, r.size * HAND_SCALE)

# 圈一个部位：圈心在部位中心，半径按部位大小。返回同 finish_stroke
func circle_part(pid: String) -> Dictionary:
	var r := part_local_rect(pid)
	if r.size == Vector2.ZERO:
		return {"kind": "none"}
	var p: Dictionary = FlawRender.part_of(session.item(iid), pid)
	var rad := clampf(maxf(r.size.x, r.size.y) / 2.0 * 0.8, 3.5 * HAND_SCALE, 22.0 * HAND_SCALE)
	return circle_at(r.get_center(), rad, str(p.get("tool", "magnifier")))

# ====================================================================
func _on_select_toggled(on: bool) -> void:
	session.set_selected(iid, on)
	if main != null:
		main.sidebar.refresh_session()

func _on_fake_toggled(on: bool) -> void:
	session.set_judged(iid, "fake" if on else "")

# Esc：先把验货收起来（全局的 Esc 菜单由别处管；册子盖在上面时让给册子）
func _input(ev: InputEvent) -> void:
	if not visible or not (ev is InputEventKey) or not ev.pressed or ev.echo or ev.keycode != KEY_ESCAPE:
		return
	if main != null and main.get("book") != null and main.book.visible:
		return
	if _drawing:
		_drawing = false
		_stroke = PackedVector2Array()
		hand_canvas.queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if _on_close():
		get_viewport().set_input_as_handled()

func _on_close() -> bool:
	if practice:
		if not _practice_done():
			_say("先圈一处，再放下。", "miss", "")
			return false
		visible = false
		emit_signal("done_practice")
		return true
	visible = false
	emit_signal("closed")
	return true
