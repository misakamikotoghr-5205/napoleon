## 战斗 HUD（出征名单、战场、战果三块高清面板）的公用件：一套主题（字体、提示框、滚动条、按钮默认样子），
## 标签、按钮、玻璃框、小药丸。样子全走 hd_theme.gd（帝国蓝金），HUD 自己的颜色走配色键 bthud_*（palette.dev.json）。
## 中文都在 data/campaigns/battle_ui.json。没有 class_name，用的地方 preload 它。说明：docs/cards/BATTLE_V2.md「高清 HUD」。
extends RefCounted

const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")

static var _theme: Theme = null


## 配色键（bthud_* 或 hd_*）
static func col(key: String) -> Color:
	return CardTheme.color(StringName(key))


## 配色键换透明度（乘在原透明度上）
static func cola(key: String, a: float = 1.0) -> Color:
	var c := col(key)
	c.a *= a
	return c


## 圆角框直接画（不建节点）：底色、圆角；edge / glow 透明度为 0 时不画
static func box(ci: CanvasItem, r: Rect2, fill: Color, radius: float) -> void:
	box_glow(ci, r, fill, radius, cola("hd_ink", 0.0), 0.0, cola("hd_ink", 0.0), 0)


static func box_edge(ci: CanvasItem, r: Rect2, fill: Color, radius: float, edge: Color, bw: float) -> void:
	box_glow(ci, r, fill, radius, edge, bw, cola("hd_ink", 0.0), 0)


static func box_glow(ci: CanvasItem, r: Rect2, fill: Color, radius: float, edge: Color, bw: float, glow: Color,
		glow_size: int) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var sb := StyleBoxFlat.new()
	sb.anti_aliasing = true
	sb.corner_detail = 10
	sb.bg_color = fill
	sb.draw_center = fill.a > 0.0
	sb.set_corner_radius_all(int(radius))
	if edge.a > 0.0 and bw > 0.0:
		sb.border_color = edge
		sb.set_border_width_all(int(bw))
	if glow.a > 0.0 and glow_size > 0:
		sb.shadow_color = glow
		sb.shadow_size = glow_size
	ci.draw_style_box(sb, r)


## 一行字画在 pos（左上角）；返回宽度
static func text(ci: CanvasItem, s: String, pos: Vector2, font: Font, fs: int, c: Color) -> float:
	return text_o(ci, s, pos, font, fs, c, c, 0)


## 同上，带描边（oc 描边色，px 描边宽）
static func text_o(ci: CanvasItem, s: String, pos: Vector2, font: Font, fs: int, c: Color, oc: Color, px: int) -> float:
	var base := pos + Vector2(0, font.get_ascent(fs))
	if px > 0 and oc.a > 0.0:
		ci.draw_string_outline(font, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, px, oc)
	ci.draw_string(font, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


## 一行字居中画在 center
static func text_c(ci: CanvasItem, s: String, center: Vector2, font: Font, fs: int, c: Color) -> void:
	text_co(ci, s, center, font, fs, c, c, 0)


static func text_co(ci: CanvasItem, s: String, center: Vector2, font: Font, fs: int, c: Color, oc: Color, px: int) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := Vector2(center.x - w * 0.5, center.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5)
	if px > 0 and oc.a > 0.0:
		ci.draw_string_outline(font, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, px, oc)
	ci.draw_string(font, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)


## 三块面板根节点的主题：默认无衬线字、浅色字、高清提示框、细金滚动条、玻璃 PanelContainer、次级按钮。
## 只建一次。像素版旧界面不用它。
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var th := Theme.new()
	th.default_font = HdTheme.font("sans")
	th.default_font_size = 15
	th.set_color(&"font_color", &"Label", col("hd_text"))
	th.set_stylebox(&"panel", &"TooltipPanel", HdTheme.panel_box("tooltip"))
	th.set_color(&"font_color", &"TooltipLabel", col("hd_text"))
	th.set_font(&"font", &"TooltipLabel", HdTheme.font("sans"))
	th.set_font_size(&"font_size", &"TooltipLabel", 14)
	var track := _flat("bthud_scroll_track", 3)
	track.content_margin_left = 2
	track.content_margin_right = 2
	th.set_stylebox(&"scroll", &"VScrollBar", track)
	th.set_stylebox(&"scroll_focus", &"VScrollBar", track)
	th.set_stylebox(&"grabber", &"VScrollBar", _flat("bthud_scroll_grab", 3))
	th.set_stylebox(&"grabber_highlight", &"VScrollBar", _flat("bthud_scroll_grab_hi", 3))
	th.set_stylebox(&"grabber_pressed", &"VScrollBar", _flat("bthud_scroll_grab_hi", 3))
	th.set_stylebox(&"panel", &"ScrollContainer", StyleBoxEmpty.new())
	th.set_stylebox(&"panel", &"PanelContainer", HdTheme.panel_box("glass"))
	th.set_stylebox(&"panel", &"Panel", StyleBoxEmpty.new())
	var probe := Button.new()
	HdTheme.apply_button(probe, "secondary")
	for st in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
		th.set_stylebox(st, &"Button", probe.get_theme_stylebox(st))
	for ck in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color",
			&"font_disabled_color", &"font_focus_color"]:
		th.set_color(ck, &"Button", probe.get_theme_color(ck))
	th.set_font(&"font", &"Button", HdTheme.font("sans"))
	th.set_font_size(&"font_size", &"Button", 15)
	probe.free()
	_theme = th
	return th


static func _flat(key: String, r: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col(key)
	sb.set_corner_radius_all(r)
	sb.anti_aliasing = true
	return sb


## 圆角纯色框（anti-aliasing）；edge 为空时没有边
static func flat(fill_key: String, fill_a: float, r: int, edge_key: String = "", edge_a: float = 1.0, bw: int = 1,
		pad: Vector2 = Vector2.ZERO) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.anti_aliasing = true
	sb.corner_detail = 10
	sb.bg_color = cola(fill_key, fill_a)
	sb.set_corner_radius_all(r)
	if edge_key != "":
		sb.border_color = cola(edge_key, edge_a)
		sb.set_border_width_all(bw)
	sb.content_margin_left = pad.x
	sb.content_margin_right = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_bottom = pad.y
	return sb


## 标签：字号、字体（serif title sans sans_bold num）、字色键
static func lbl(text: String, font_size: int, kind: String = "sans", color_key: String = "hd_text") -> Label:
	var own := not color_key.begins_with("hd_")
	var l := HdTheme.make_label(text, font_size, kind, "hd_text" if own else color_key)
	if own:
		l.add_theme_color_override(&"font_color", col(color_key))
	return l


## 自动换行的标签（宽度固定）
static func wrap(text: String, width: float, font_size: int, kind: String = "sans", color_key: String = "hd_text_2") -> Label:
	var l := lbl(text, font_size, kind, color_key)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	l.size = Vector2(width, 0)
	return l


## 字上描一道深色边（压在地图上的字）
static func outline(l: Label, px: int = 4, key: String = "hd_ink", a: float = 0.85) -> Label:
	l.add_theme_constant_override(&"outline_size", px)
	l.add_theme_color_override(&"font_outline_color", cola(key, a))
	return l


## 按钮：hd_theme 的样子（primary secondary danger ghost choice icon）；字号 <= 0 用样子自带的
static func button(text: String, node_name: String, kind: String = "secondary", font_size: int = 0) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	HdTheme.apply_button(b, kind)
	if font_size > 0:
		b.add_theme_font_size_override(&"font_size", font_size)
	return b


## 紧凑按钮（顶栏、牌组标题行）：在 hd_theme 的样子上把内边距和最小高度收小
static func small_button(text: String, node_name: String, kind: String = "secondary", font_size: int = 14,
		pad: Vector2 = Vector2(12, 4), min_h: float = 30.0) -> Button:
	var b := button(text, node_name, kind, font_size)
	for st in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var sb := b.get_theme_stylebox(st)
		if sb != null:
			sb.content_margin_left = pad.x
			sb.content_margin_right = pad.x
			sb.content_margin_top = pad.y
			sb.content_margin_bottom = pad.y
	b.custom_minimum_size = Vector2(0, min_h)
	return b


## 一块玻璃框（PanelContainer，按内容撑开）
static func glass(kind: String = "glass", node_name: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	if node_name != "":
		p.name = node_name
	p.add_theme_stylebox_override(&"panel", HdTheme.panel_box(kind))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


## 一块定位好的玻璃底（Panel，不接鼠标）
static func plate(rect: Rect2, kind: String = "glass", node_name: String = "") -> Panel:
	var p := Panel.new()
	if node_name != "":
		p.name = node_name
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override(&"panel", HdTheme.panel_box(kind))
	return p


## 小药丸标签（伤痕、猎官、档位……）
static func pill(text: String, fill_key: String, ink_key: String = "hd_text", font_size: int = 12, fill_a: float = 1.0,
		edge_key: String = "") -> PanelContainer:
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := flat(fill_key, fill_a, 9, edge_key, 0.8, 1, Vector2(7, 1))
	pc.add_theme_stylebox_override(&"panel", sb)
	var l := lbl(text, font_size, "sans_bold", ink_key)
	l.remove_theme_color_override(&"font_shadow_color")
	pc.add_child(l)
	return pc


## 一段竖排（VBoxContainer，不接鼠标）
static func vbox(sep: int = 4, node_name: String = "") -> VBoxContainer:
	var v := VBoxContainer.new()
	if node_name != "":
		v.name = node_name
	v.add_theme_constant_override(&"separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


static func hbox(sep: int = 4, node_name: String = "") -> HBoxContainer:
	var h := HBoxContainer.new()
	if node_name != "":
		h.name = node_name
	h.add_theme_constant_override(&"separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


## 透明的整块按钮（卡片接点击；样子由底下画的东西决定），鼠标变手形
static func hit(node_name: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for st in [&"normal", &"hover", &"pressed", &"disabled", &"focus", &"hover_pressed"]:
		b.add_theme_stylebox_override(st, empty)
	return b


## 有滚动条的一栏（竖向，内容超出时滚轮滚动）
static func scroller(rect: Rect2, node_name: String) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.name = node_name
	sc.position = rect.position
	sc.size = rect.size
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	return sc


static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## 单位用哪张头像 / 立绘：主角 villefort，伙伴自己的 id，部队 troop_<兵种>，敌人 enemy_<种类>
static func art_id(uid: String, kind: String, cls: String) -> String:
	match kind:
		"hero":
			return "villefort"
		"companion":
			return uid
		"barricade":
			return "troop_engineer"
	return "troop_" + cls

