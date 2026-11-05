## 战斗 v2 界面的公用小件：中文文字（全在 data/campaigns/battle_ui.json）、单位身上的字、按钮和小标签。
## 没有 class_name，三块面板和格子 preload 它。颜色一律走 CardTheme.color（配色键 bt_* 在 palette.dev.json）。
extends RefCounted

const DATA_PATH := "res://data/campaigns/battle_ui.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(DATA_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			_data = parsed
	return _data


## 一条文字；args 填 {占位符}（数字按整数写）
static func text(key: String, args: Dictionary = {}) -> String:
	var raw = data().get("text", {}).get(key, key)
	return _fill(str(raw), args)


## 文字表里的一组（kind、unit_state、tag、err）里的一项；没有就回空串
static func pick(group: String, key: String, args: Dictionary = {}) -> String:
	var g = data().get("text", {}).get(group, {})
	if typeof(g) != TYPE_DICTIONARY or not g.has(key):
		return ""
	return _fill(str(g[key]), args)


## 指令被拒绝时给玩家看的一句话
static func err(code: String) -> String:
	var line := pick("err", code)
	return line if line != "" else pick("err", "other", {"err": code})


static func cls_char(cls: String) -> String:
	return str(data().get("cls_char", {}).get(cls, "?"))


static func enemy_char(kind: String) -> String:
	return str(data().get("enemy_char", {}).get(kind, "?"))


## 格子标签 A1：列字母 + 行号（行 1 在最上）
static func label(c: int, r: int) -> String:
	return "%s%d" % [char(65 + c), r + 1]


static func join(names: Array) -> String:
	return text("list_sep").join(PackedStringArray(names))


static func _fill(line: String, args: Dictionary) -> String:
	if args.is_empty():
		return line
	var clean := {}
	for k in args:
		var v = args[k]
		clean[k] = str(int(v)) if typeof(v) == TYPE_FLOAT else str(v)
	return line.format(clean)


# ---------------------------------------------------------------- 节点小件

static func lbl(text_value: String, size: int = 14, tone: StringName = &"hud_ink", bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", CardTheme.color(tone))
	if bold:
		l.add_theme_font_override("font", CardTheme.font_body_bold())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrap(text_value: String, width: float, size: int = 13, tone: StringName = &"text_2") -> Label:
	var l := lbl(text_value, size, tone)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	l.size = Vector2(width, 0)
	return l


static func button(text_value: String, node_name: String, variation: StringName = &"", size: int = 15) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text_value
	b.focus_mode = Control.FOCUS_NONE
	if variation != &"":
		b.theme_type_variation = variation
	b.add_theme_font_size_override("font_size", size)
	return b


## 小按钮：自己的扁样式，不吃主题按钮的最小高度（部署栏、战报标题行、主角框里放得下）
static func small_button(text_value: String, node_name: String, size: int = 11) -> Button:
	var b := button(text_value, node_name, &"", size)
	for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		var bg: StringName = &"gold_deep" if st in ["hover", "pressed", "hover_pressed"] else &"wood_0"
		var sb := box_style(bg, &"gold_deep", 1, 3, 2.0)
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", CardTheme.color(&"gold_pale"))
	b.add_theme_color_override("font_hover_color", CardTheme.color(&"bt_token_ink"))
	b.add_theme_color_override("font_pressed_color", CardTheme.color(&"bt_token_ink"))
	b.add_theme_color_override("font_disabled_color", CardTheme.color(&"text_3"))
	return b


## 一块深色圆角底（面板分区、弹出的动作菜单）
static func box_style(bg: StringName = &"bt_pill_bg", edge: StringName = &"line", border: int = 1, radius: int = 4,
		pad: float = 6.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CardTheme.color(bg)
	sb.border_color = CardTheme.color(edge)
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


static func panel_box(rect: Rect2, bg: StringName = &"bt_pill_bg", edge: StringName = &"line") -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", box_style(bg, edge))
	return p


## 一个小药丸标签（伤痕、宿命之地、猎官……）
static func pill(text_value: String, bg: StringName, ink: StringName = &"bt_token_ink", size: int = 12) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = CardTheme.color(bg)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 0
	sb.content_margin_bottom = 1
	pc.add_theme_stylebox_override("panel", sb)
	pc.add_child(lbl(text_value, size, ink))
	return pc


## 透明的整块按钮（格子、名单行、部署牌都用它接点击；样子由底下画的东西决定）
static func flat_button(node_name: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(st, empty)
	return b


static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


## 主角或伙伴与否、兵种，决定部署牌和格子上单位的底色
static func unit_fill(kind: String, cls: String) -> StringName:
	if cls == "barricade":
		return &"bt_barricade"
	if kind == "hero":
		return &"bt_hero"
	return &"bt_ally"


static func font() -> Font:
	return CardTheme.font_body()


static func font_bold() -> Font:
	return CardTheme.font_body_bold()
