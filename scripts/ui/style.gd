# 界面样式：木、纸、靛蓝布、印泥红（设计稿“美术与音效要求”）。所有面板用这里的工厂函数。
extends RefCounted
class_name UiStyle

const WOOD_DARK := Color("#1f1712")
const WOOD := Color("#3a2a1e")
const WOOD_MID := Color("#5a3f2a")
const PAPER := Color("#f4e2b0")
const PAPER_OLD := Color("#d9c49a")
const INK := Color("#1f1712")
const INK_SOFT := Color("#5a3f2a")
const LAMP := Color("#ffd25a")
const LAMP_PALE := Color("#e8c88a")
const SEAL := Color("#b0262a")
const INDIGO := Color("#2f4670")
const MIST := Color("#9aa4aa")
const GOOD := Color("#4a6a3a")

static var _title_font: Font = null
static var _body_font: Font = null

static func title_font() -> Font:
	if _title_font == null:
		var f := FontVariation.new()
		f.base_font = load("res://fonts/MaShanZheng-Title-subset.ttf")
		f.fallbacks = [load("res://fonts/NotoSerifSC-Regular-subset.otf")]
		_title_font = f
	return _title_font

static func body_font() -> Font:
	if _body_font == null:
		_body_font = load("res://fonts/NotoSerifSC-Regular-subset.otf")
	return _body_font

static func box(bg: Color, border: Color = WOOD_DARK, bw: int = 3, radius: int = 2, pad: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	return s

static func paper_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(PAPER, WOOD, 4, 3, 14))
	return p

static func wood_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(WOOD_DARK, WOOD_MID, 3, 2, 10))
	return p

static func label(text: String, size: int = 18, color: Color = INK, wrap: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func title_label(text: String, size: int = 30, color: Color = INK) -> Label:
	var l := label(text, size, color, false)
	l.add_theme_font_override("font", title_font())
	return l

static func button(text: String, size: int = 17, kind: String = "paper", wrap: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	var base := PAPER_OLD if kind == "paper" else (Color("#6e1a1c") if kind == "seal" else WOOD)
	var fg := INK if kind == "paper" else PAPER
	b.add_theme_stylebox_override("normal", box(base, WOOD, 2, 3, 8))
	b.add_theme_stylebox_override("hover", box(base.lightened(0.15), SEAL, 2, 3, 8))
	b.add_theme_stylebox_override("pressed", box(base.darkened(0.15), SEAL, 2, 3, 8))
	b.add_theme_stylebox_override("disabled", box(base.darkened(0.25), WOOD, 2, 3, 8))
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", fg.darkened(0.35) if kind == "paper" else MIST)
	if wrap:
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return b

static func hsep(color: Color = WOOD_MID) -> ColorRect:
	var c := ColorRect.new()
	c.color = color
	c.custom_minimum_size = Vector2(0, 2)
	return c

static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s

static func vbox(sep: int = 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep: int = 6) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

# 中文大写数字点缀（账簿、当票）
static func cn_money(n: int) -> String:
	var d := ["零", "壹", "贰", "叁", "肆", "伍", "陆", "柒", "捌", "玖"]
	if n == 0:
		return "零"
	var units := ["", "拾", "佰", "仟", "万"]
	var s := str(n)
	var out := ""
	for i in range(s.length()):
		var digit := int(s[i])
		var u: String = units[s.length() - 1 - i] if s.length() - 1 - i < units.size() else ""
		if digit == 0:
			if not out.ends_with("零"):
				out += "零"
		else:
			out += d[digit] + u
	while out.ends_with("零") and out.length() > 1:
		out = out.substr(0, out.length() - 1)
	return out
