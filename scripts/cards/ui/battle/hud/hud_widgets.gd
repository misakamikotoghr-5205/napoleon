## 战斗 HUD 的小件（内部类，用的地方 preload 这个文件再 W.Bar.new()）：
##   Bar        圆角进度条：兵力、军心；交火后的预演（掉的那截琥珀色、涨的那截淡色）、档位刻度
##   Pips       回合进度：一排小菱形
##   Shade      满屏的上下暗带（地图融进 HUD）
##   DeployCard 部署牌：头像、费用、兵种字、名字、兵力条、状态 / 冷却遮罩、选中抬起
##   CmdCard    军令牌：羊皮纸、蜡封里的费用、名字、说明
##   RoundAct   单位身边的圆形动作按钮（技能带充能圈）
##   FaceArrow  部署时选朝向的箭头
##   Stars      战果的三颗星
##   Rule       标题两侧的金线和菱形
## 只画，颜色走配色键（bthud_* / hd_*），字由调用方从 battle_ui.json 取好传进来。没有 class_name。
extends RefCounted

const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const D = preload("res://scripts/cards/ui/hd/hd_draw.gd")
const Kit = preload("res://scripts/cards/ui/battle/hud/hud_kit.gd")
const Portrait = preload("res://scripts/cards/ui/battle/hud/hud_portrait.gd")


# ================================================================ 进度条

class Bar extends Control:
	var value := 0
	var cap := 1
	## 交火后的值（< 0 = 没有预演）
	var after := -1
	var fill_key := "bthud_morale"
	var hi_key := "bthud_morale_hi"
	var loss_key := "bthud_loss"
	## 刻度：[[位置, 配色键], ...]
	var ticks: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func set_values(v: int, c: int, a: int = -1) -> void:
		value = v
		cap = maxi(1, c)
		after = a
		queue_redraw()

	func _x(v: float, inner: Rect2) -> float:
		return inner.position.x + inner.size.x * clampf(v / float(cap), 0.0, 1.0)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if r.size.x < 6.0 or r.size.y < 3.0:
			return
		var rad := floorf(r.size.y * 0.5)
		Kit.box_edge(self, r, Kit.cola("bthud_bar_track"), rad, Kit.cola("hd_gold", 0.32), 1.0)
		var inner := r.grow(-2.0)
		var irad := maxf(rad - 2.0, 1.0)
		var shown := value if after < 0 else mini(value, after)
		var x_shown := _x(shown, inner)
		if after > value:
			Kit.box(self, Rect2(inner.position, Vector2(_x(after, inner) - inner.position.x, inner.size.y)), Kit.cola(hi_key, 0.35), irad)
		if after >= 0 and after < value:
			Kit.box(self, Rect2(inner.position, Vector2(_x(value, inner) - inner.position.x, inner.size.y)), Kit.cola(loss_key), irad)
		if x_shown - inner.position.x >= 1.0:
			var fr := Rect2(inner.position, Vector2(x_shown - inner.position.x, inner.size.y))
			Kit.box(self, fr, Kit.cola(fill_key), irad)
			if fr.size.y >= 5.0 and fr.size.x > 4.0:
				Kit.box(self, Rect2(fr.position + Vector2(1, 1), Vector2(fr.size.x - 2.0, fr.size.y * 0.42)), Kit.cola(hi_key, 0.45),
					maxf(irad - 1.0, 1.0))
		for tk in ticks:
			var tx := _x(float(tk[0]), inner)
			draw_line(Vector2(tx, -2), Vector2(tx, r.size.y + 2), Kit.cola(str(tk[1])), 2.0, true)
		if after >= 0 and after != value:
			var ax := _x(after, inner)
			draw_line(Vector2(ax, -3), Vector2(ax, r.size.y + 3), Kit.cola("hd_white", 0.9), 1.5, true)


# ================================================================ 回合菱形

class Pips extends Control:
	var turn := 0
	var limit := 1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_turn(t: int, l: int) -> void:
		turn = t
		limit = maxi(1, l)
		queue_redraw()

	func _draw() -> void:
		var n := mini(limit, 16)
		var gap := minf(13.0, size.x / float(maxi(n, 1)))
		var x0 := size.x * 0.5 - gap * (n - 1) * 0.5
		var y := size.y * 0.5
		draw_line(Vector2(x0 - 10, y), Vector2(x0 + gap * (n - 1) + 10, y), Kit.cola("hd_gold", 0.18), 1.0, true)
		for i in range(n):
			var p := Vector2(x0 + gap * i, y)
			var t := i + 1
			if t < turn:
				D.diamond(self, p, 3.0, Kit.cola("hd_gold", 0.8))
			elif t == turn:
				D.glow(self, Rect2(p - Vector2(10, 10), Vector2(20, 20)), Kit.cola("hd_gold_hi", 0.7))
				D.diamond(self, p, 4.8, Kit.cola("hd_gold_hi"))
			else:
				var pts := PackedVector2Array([p + Vector2(0, -3), p + Vector2(3, 0), p + Vector2(0, 3), p + Vector2(-3, 0),
					p + Vector2(0, -3)])
				draw_polyline(pts, Kit.cola("hd_gold", 0.4), 1.0, true)


# ================================================================ 满屏暗带

class Shade extends Control:
	var top := 130.0
	var bottom := 220.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var clear := Kit.cola("hd_ink", 0.0)
		D.vgrad(self, Rect2(0, 0, size.x, top), [[0.0, Kit.cola("hd_ink", 0.72)], [0.45, Kit.cola("hd_ink", 0.3)], [1.0, clear]])
		D.vgrad(self, Rect2(0, size.y - bottom, size.x, bottom), [[0.0, clear], [0.55, Kit.cola("hd_ink", 0.5)],
			[1.0, Kit.cola("hd_ink", 0.86)]])


# ================================================================ 标题金线

class Rule extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y * 0.5
		D.fade_line(self, Vector2(0, y), Vector2(size.x, y), Kit.cola("hd_gold", 0.8), 1.0)
		D.diamond(self, Vector2(size.x * 0.5, y), 3.5, Kit.cola("hd_gold_hi"))


# ================================================================ 部署牌

## 部署牌：setup() 搭一次，set_state() 每次视图变了改字和状态。按钮（Deploy_<uid>）盖满整张；
## 主角那张在能后方调度时下半截换成「后方调度」按钮（Dispatch_hero）。
class DeployCard extends Control:
	const PH := 70.0
	var ph := PH
	var uid := ""
	var portrait: Control
	var deco: Control
	var name_l: Label
	var sub_l: Label
	var btn: Button
	var dispatch: Button = null
	var picked := false
	var hovered := false
	var on := true
	var deployable := false
	var cost := 0
	var cost_bad := false
	var glyph := ""
	var tag := ""
	var tag_key := "bthud_tag_troop"
	var state_text := ""
	var state_key := "bthud_state_field"
	var cooldown := 0
	var cd_word := ""
	var hp := 0
	var max_hp := 1
	var accent: Color
	var base_y := 0.0
	var _tw: Tween = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(80, 104)

	func setup(b: Dictionary, art_id: String, accent_id: String, cls_glyph: String, display: String, sub_tag: String,
			tag_color: String, dispatch_text: String) -> void:
		uid = str(b["uid"])
		glyph = cls_glyph
		tag = sub_tag
		tag_key = tag_color
		portrait = Portrait.new()
		portrait.position = Vector2(3, 3)
		portrait.size = Vector2(size.x - 6, PH)
		portrait.setup(art_id, display, accent_id)
		accent = portrait.accent
		add_child(portrait)
		deco = Deco.new()
		deco.card = self
		deco.size = size
		add_child(deco)
		name_l = Kit.lbl(display, 13, "sans_bold", "hd_text")
		name_l.name = "Name"
		name_l.position = Vector2(2, PH + 5)
		name_l.size = Vector2(size.x - 4, 16)
		name_l.clip_text = true
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(name_l)
		sub_l = Kit.lbl("", 11, "sans", "hd_text_2")
		sub_l.position = Vector2(2, PH + 20)
		sub_l.size = Vector2(size.x - 4, 13)
		sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(sub_l)
		btn = Kit.hit("Deploy_" + uid)
		btn.size = size
		btn.mouse_entered.connect(_hover.bind(true))
		btn.mouse_exited.connect(_hover.bind(false))
		add_child(btn)
		if dispatch_text != "":
			dispatch = Kit.small_button(dispatch_text, "Dispatch_" + uid, "primary", 12, Vector2(2, 1), 24)
			dispatch.position = Vector2(4, size.y - 29)
			dispatch.size = Vector2(size.x - 8, 25)
			dispatch.visible = false
			add_child(dispatch)

	func _hover(h: bool) -> void:
		hovered = h and not btn.disabled
		_lift()
		deco.queue_redraw()

	func _lift() -> void:
		var target := base_y - (12.0 if picked else (4.0 if hovered else 0.0))
		if is_equal_approx(position.y, target):
			return
		if _tw != null and _tw.is_valid():
			_tw.kill()
		if not is_inside_tree():
			position.y = target
			return
		_tw = create_tween()
		_tw.tween_property(self, "position:y", target, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	func place(x: float, y: float, w: float) -> void:
		size = Vector2(w, size.y)
		base_y = y
		position = Vector2(x, y - (12.0 if picked else 0.0))
		portrait.size = Vector2(w - 6, PH)
		deco.size = size
		name_l.size = Vector2(w - 4, 16)
		sub_l.size = Vector2(w - 4, 13)
		btn.size = Vector2(w, btn.size.y)
		if dispatch != null:
			dispatch.size = Vector2(w - 8, 25)

	func set_state(p_on: bool, p_picked: bool, p_deployable: bool, p_cost: int, p_cost_bad: bool, sub: String,
			st_text: String, st_key: String, cd: int, cd_text: String, p_hp: int, p_max: int, show_dispatch: bool) -> void:
		on = p_on
		deployable = p_deployable
		cost = p_cost
		cost_bad = p_cost_bad
		state_text = st_text
		state_key = st_key
		cooldown = cd
		cd_word = cd_text
		hp = p_hp
		max_hp = maxi(1, p_max)
		sub_l.text = sub
		sub_l.visible = not show_dispatch
		name_l.add_theme_color_override(&"font_color", Kit.cola("hd_text" if on else "hd_text_3"))
		portrait.dim = not on
		btn.disabled = not deployable
		btn.size = Vector2(size.x, size.y - 31.0) if show_dispatch else size
		if dispatch != null:
			dispatch.visible = show_dispatch
		if picked != p_picked:
			picked = p_picked
		if btn.disabled:
			hovered = false
		_lift()
		deco.queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		Kit.box_glow(self, r, Kit.cola("hd_card", 0.97), 6.0, Kit.cola("hd_ink", 0.0), 0.0, Kit.cola("hd_shadow", 0.55), 8)

	## 画在头像上面的：渐变底、费用、兵种字、兵力条、小标签、状态 / 冷却遮罩、边框
	class Deco extends Control:
		var card = null

		func _init() -> void:
			mouse_filter = Control.MOUSE_FILTER_IGNORE

		func _draw() -> void:
			if card == null:
				return
			var w := size.x
			var ph: float = card.ph
			var pr := Rect2(3, 3, w - 6, ph)
			D.vgrad(self, Rect2(3, ph * 0.5, w - 6, ph * 0.5 + 3), [[0.0, Kit.cola("hd_ink", 0.0)], [1.0, Kit.cola("hd_ink", 0.7)]])
			var blocked: bool = card.cooldown > 0 or (card.state_text != "" and not card.deployable)
			if blocked:
				Kit.box(self, pr, Kit.cola("hd_ink", 0.6), 4.0)
			var f := HdTheme.font("num")
			var fb := HdTheme.font("sans_bold")
			var bar := Rect2(5, ph - 1, w - 10, 4)
			Kit.box(self, bar, Kit.cola("bthud_bar_track"), 2.0)
			var frac := clampf(float(card.hp) / float(card.max_hp), 0.0, 1.0)
			if frac > 0.0:
				Kit.box(self, Rect2(bar.position, Vector2(maxf(bar.size.x * frac, 3.0), bar.size.y)),
					Kit.cola("bthud_hp" if frac > 0.34 else "bthud_hp_low"), 2.0)
			var cr := Rect2(1, 1, 24, 21)
			Kit.box_edge(self, cr, Kit.cola("bthud_cost_bg", 0.95), 5.0, Kit.cola("hd_gold", 0.8), 1.0)
			Kit.text_c(self, str(card.cost), cr.get_center(), f, 15, Kit.cola("bthud_cost_bad" if card.cost_bad else "bthud_cost_ink"))
			var gc := Vector2(w - 13, 13)
			draw_circle(gc, 10.5, Kit.cola("hd_ink", 0.88), true, -1.0, true)
			draw_arc(gc, 10.5, 0, TAU, 40, card.accent, 1.5, true)
			Kit.text_c(self, card.glyph, gc, HdTheme.font("title"), 12, Kit.cola("hd_gold_hi"))
			if card.tag != "":
				var tw: float = fb.get_string_size(card.tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 10.0
				var tr := Rect2(4, ph - 17, tw, 14)
				Kit.box(self, tr, Kit.cola(card.tag_key, 0.92), 7.0)
				Kit.text_c(self, card.tag, tr.get_center(), fb, 10, Kit.cola("hd_text"))
			if card.cooldown > 0:
				Kit.text_co(self, str(card.cooldown), pr.get_center() + Vector2(0, -7), f, 28, Kit.cola("hd_gold_hi"),
					Kit.cola("hd_ink", 0.8), 4)
				Kit.text_co(self, card.cd_word, pr.get_center() + Vector2(0, 16), fb, 11, Kit.cola("hd_text_2"),
					Kit.cola("hd_ink", 0.8), 3)
			elif blocked:
				var sw: float = fb.get_string_size(card.state_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 16.0
				var sr := Rect2(pr.get_center() - Vector2(sw * 0.5, 9), Vector2(sw, 18))
				Kit.box_edge(self, sr, Kit.cola(card.state_key, 0.95), 9.0, Kit.cola("hd_white", 0.25), 1.0)
				Kit.text_c(self, card.state_text, sr.get_center(), fb, 12, Kit.cola("hd_text"))
			var r := Rect2(Vector2.ZERO, size)
			if card.picked:
				Kit.box_glow(self, r.grow(1), Kit.cola("hd_ink", 0.0), 7.0, Kit.cola("hd_gold_hi"), 2.0, Kit.cola("hd_gold", 0.55), 12)
			elif card.hovered:
				Kit.box_edge(self, r, Kit.cola("hd_ink", 0.0), 6.0, Kit.cola("hd_gold_hi", 0.95), 1.5)
			else:
				Kit.box_edge(self, r, Kit.cola("hd_ink", 0.0), 6.0, Kit.cola("hd_gold", 0.6 if card.deployable else 0.22), 1.0)


# ================================================================ 军令牌

class CmdCard extends Control:
	var cost := 0
	var title := ""
	var desc := ""
	var lock_text := ""
	## 底下那行小签的颜色：扣在方阵是蓝的，打不出的原因（军令点不够、没有目标）是红的
	var lock_blue := true
	var playable := true
	var picked := false
	var hovered := false
	var btn: Button
	var base_y := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(120, 100)

	func setup(idx: int, p_cost: int, p_title: String, p_desc: String, p_lock: String, p_playable: bool, p_picked: bool,
			enabled: bool, tip: String) -> void:
		cost = p_cost
		title = p_title
		desc = p_desc
		lock_text = p_lock
		playable = p_playable
		picked = p_picked
		# 名字放得下最好：标题字（带字距）15 往下缩到 11；还放不下换不带字距的衬线字缩到 10；再不行省略号，全名在悬停提示里
		var room := size.x - 40.0
		var fs := 15
		var kind := "title"
		var tf := HdTheme.font("title")
		while fs > 11 and tf.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
			fs -= 1
		if tf.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
			kind = "serif"
			tf = HdTheme.font("serif")
			fs = 12
			while fs > 10 and tf.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
				fs -= 1
		var nm := Kit.lbl(title, fs, kind, "hd_parchment_ink")
		nm.name = "Name"
		nm.remove_theme_color_override(&"font_shadow_color")
		nm.position = Vector2(36, 18 - 10)
		nm.size = Vector2(size.x - 38, 20)
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		add_child(nm)
		var dl := Kit.lbl(desc, 11, "sans", "hd_parchment_ink")
		dl.remove_theme_color_override(&"font_shadow_color")
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.position = Vector2(9, 33)
		dl.size = Vector2(size.x - 16, size.y - 38 - (16.0 if lock_text != "" else 0.0))
		dl.clip_text = true
		dl.max_lines_visible = 4 if lock_text == "" else 3
		dl.add_theme_constant_override(&"line_spacing", -2)
		add_child(dl)
		btn = Kit.hit("Card_%d" % idx)
		btn.size = size
		btn.disabled = not enabled
		btn.tooltip_text = tip if tip.contains(title) else (title + ("\n" + tip if tip != "" else ""))
		btn.mouse_entered.connect(_hover.bind(true))
		btn.mouse_exited.connect(_hover.bind(false))
		add_child(btn)
		modulate = Kit.cola("hd_white") if playable or picked else Kit.cola("bthud_dim")

	func _hover(h: bool) -> void:
		hovered = h and not btn.disabled
		_lift()

	func place(x: float, y: float) -> void:
		base_y = y
		position = Vector2(x, y - (10.0 if picked else 0.0))

	func _lift() -> void:
		position.y = base_y - (10.0 if picked else (4.0 if hovered else 0.0))
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if picked:
			Kit.box_glow(self, r.grow(2), Kit.cola("hd_ink", 0.0), 8.0, Kit.cola("hd_gold_hi"), 2.0, Kit.cola("hd_gold", 0.6), 14)
		draw_style_box(HdTheme.panel_box("parchment"), r)
		if hovered and not picked:
			Kit.box_edge(self, r, Kit.cola("hd_ink", 0.0), 6.0, Kit.cola("hd_gold_deep"), 2.0)
		var sc := Vector2(20, 18)
		draw_circle(sc + Vector2(0, 1.5), 13.5, Kit.cola("hd_shadow", 0.35), true, -1.0, true)
		for i in range(10):
			var a := TAU * i / 10.0
			draw_circle(sc + Vector2(cos(a), sin(a)) * 12.4, 2.6, Kit.cola("hd_wax"), true, -1.0, true)
		draw_circle(sc, 13.0, Kit.cola("hd_wax"), true, -1.0, true)
		draw_arc(sc, 10.0, 0, TAU, 36, Kit.cola("hd_wax_hi"), 1.5, true)
		Kit.text_c(self, str(cost), sc, HdTheme.font("num"), 15, Kit.cola("hd_text"))
		D.fade_line(self, Vector2(8, 30), Vector2(size.x - 8, 30), Kit.cola("hd_gold_deep", 0.75), 1.0)
		if lock_text != "":
			var fb := HdTheme.font("sans_bold")
			var tw := fb.get_string_size(lock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 12.0
			var lr := Rect2(8, size.y - 19, tw, 14)
			Kit.box(self, lr, Kit.cola("hd_ally" if lock_blue else "hd_wax_hi"), 7.0)
			Kit.text_c(self, lock_text, lr.get_center(), fb, 10, Kit.cola("hd_text"))


# ================================================================ 单位身边的圆按钮

## 圆形动作按钮：底、金圈、中间一个字，下面一行说明；ring >= 0 时画充能圈（技能）；ready 时金色发光
class RoundAct extends Button:
	var glyph := ""
	var caption := ""
	## true：说明字只在悬停时画（单位身边一圈按钮用；常显会压到邻格）
	var caption_on_hover := false
	var ring := -1.0
	var lit := false
	var tone := "gold"

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		for st in [&"normal", &"hover", &"pressed", &"disabled", &"focus", &"hover_pressed"]:
			add_theme_stylebox_override(st, empty)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 4.0
		var hot := is_hovered() and not disabled
		var edge := "hd_gold_hi"
		var fill := "hd_navy_2"
		match tone:
			"danger":
				edge = "hd_enemy_hi"
				fill = "hd_wax"
			"ally":
				edge = "hd_ally_hi"
				fill = "hd_navy_3"
		var on := lit and not disabled
		D.glow(self, Rect2(c - Vector2(r, r) * 1.7, Vector2(r, r) * 3.4), Kit.cola("hd_shadow", 0.6))
		if lit:
			D.glow(self, Rect2(c - Vector2(r, r) * 2.0, Vector2(r, r) * 4.0), Kit.cola("hd_gold", 0.6))
		var base := Kit.cola(fill, 0.96)
		if lit:
			base = Kit.cola("hd_gold_deep").lerp(Kit.cola("hd_gold"), 0.45)
		if hot:
			base = base.lightened(0.14)
		if disabled:
			base = Kit.cola("hd_ink", 0.88)
		draw_circle(c, r, base, true, -1.0, true)
		draw_circle(c + Vector2(0, -r * 0.42), r * 0.55, Kit.cola("hd_white", 0.07), true, -1.0, true)
		draw_arc(c, r, 0, TAU, 64, Kit.cola(edge, 0.35 if disabled else (1.0 if hot else 0.85)), 1.5, true)
		if ring >= 0.0:
			draw_arc(c, r + 4.0, 0, TAU, 64, Kit.cola("bthud_ring_track"), 3.0, true)
			if ring > 0.0:
				draw_arc(c, r + 4.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(ring, 0.0, 1.0), 64,
					Kit.cola("hd_gold_hi" if ring >= 1.0 else "bthud_ring_fill"), 3.0, true)
		var ink := Kit.cola("hd_ink") if lit else Kit.cola("hd_text_3" if disabled else "hd_gold_hi")
		Kit.text_c(self, glyph, c, HdTheme.font("title"), maxi(int(r * 0.9), 8), ink)
		if caption != "" and (not caption_on_hover or is_hovered()):
			Kit.text_co(self, caption, Vector2(c.x, size.y + 8), HdTheme.font("sans_bold"), 12,
				Kit.cola("hd_text" if not disabled else "hd_text_3"), Kit.cola("hd_ink", 0.92), 5)


# ================================================================ 朝向箭头

class FaceArrow extends Button:
	var dir := "right"
	## 屏幕上的方向（按相机投影算，斜着的地图上不一定是正右）
	var vec := Vector2.RIGHT

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		for st in [&"normal", &"hover", &"pressed", &"disabled", &"focus", &"hover_pressed"]:
			add_theme_stylebox_override(st, empty)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 3.0
		var hot := is_hovered()
		D.glow(self, Rect2(c - Vector2(r, r) * 1.7, Vector2(r, r) * 3.4), Kit.cola("hd_gold" if hot else "hd_shadow", 0.55))
		draw_circle(c, r, Kit.cola("hd_gold") if hot else Kit.cola("hd_navy", 0.94), true, -1.0, true)
		draw_arc(c, r, 0, TAU, 48, Kit.cola("hd_gold_hi"), 1.5, true)
		var v := vec.normalized()
		var n := Vector2(-v.y, v.x)
		var s := r * 0.52
		var pts := PackedVector2Array([c + v * s, c - v * s * 0.45 + n * s * 0.95, c - v * s * 0.05, c - v * s * 0.45 - n * s * 0.95])
		D.poly(self, pts, Kit.cola("hd_ink") if hot else Kit.cola("hd_gold_hi"), 1.0)


# ================================================================ 星级

class Stars extends Control:
	var count := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var step := size.x / 3.0
		for i in range(3):
			var big := 1.0 if i == 1 else 0.8
			var c := Vector2(step * (i + 0.5), size.y * (0.46 if i == 1 else 0.56))
			var rad := size.y * 0.44 * big
			var pts := PackedVector2Array()
			for k in range(10):
				var a := -PI * 0.5 + k * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * (rad if k % 2 == 0 else rad * 0.45))
			var lit := i < count
			if lit:
				D.glow(self, Rect2(c - Vector2(rad, rad) * 1.9, Vector2(rad, rad) * 3.8), Kit.cola("hd_gold", 0.5))
				D.poly_colors(self, pts, D.colors_by_y(pts, c.y - rad, c.y + rad, Kit.cola("hd_gold_hi"), Kit.cola("hd_gold_deep")), 1.2)
			else:
				D.poly(self, pts, Kit.cola("hd_ink", 0.78), 1.0)
			var ring := pts.duplicate()
			ring.append(pts[0])
			draw_polyline(ring, Kit.cola("hd_gold_hi" if lit else "hd_gold", 0.95 if lit else 0.45), 1.5, true)
