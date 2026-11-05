# 抽屉里面的公共样子（换皮 10-22，照网页原型的抽屉）：深底浅字、金色小节标题、说明小字、药丸、批注条、纸片、头像。
# 人脉（C03）、条子（C05）、档案簿与规矩（C10）、家当（C11）共用。主人 C03。不写 class_name（preload）。
# 抽屉框和标题行是 C01 的 drawer_host 画的；这里只管框里面那块：合同 §7.11.8，左 368x630、右 388x630，
# 框内边距 16；标题行高度跟 drawer_host 的 HEAD_H（另加 1px 分隔线）。颜色只走 CardTheme，字只走 CardText（调用方传进来）。
extends RefCounted

const DrawerHost = preload("res://scripts/cards/ui/table/drawer_host.gd")
const INSET := 16.0
const TITLE_H := DrawerHost.HEAD_H + 1.0   # 抽屉框标题行（合并时统一成 C01 的 52）
const TOP_PAD := 8.0


## 抽屉内容区（屏幕坐标）。side "l" / "r"。
static func rect(side: String) -> Rect2:
	var frame := CardLayout.DRAWER_L if side == "l" else CardLayout.DRAWER_R
	return Rect2(frame.position.x + INSET, frame.position.y + TITLE_H,
		frame.size.x - INSET * 2.0, frame.size.y - TITLE_H - INSET)


## 把抽屉面板摆进内容区：宿主先把面板钉在 (0,0,1280,720)，这里改成框里那块，只在这块吃鼠标。
static func place(panel: Control, side: String) -> void:
	var r := rect(side)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = r.position
	panel.custom_minimum_size = r.size
	panel.size = r.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP


## 一行字。tone 是配色键；bold 用正文加粗；wrap 自动换行（换行的字要给宽度）。
static func label(text: String, size: int = 14, tone: StringName = &"hud_ink", bold: bool = false,
		wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", CardTheme.font_body_bold() if bold else CardTheme.font_body())
	l.add_theme_font_size_override("font_size", maxi(size, CardTheme.font_size(&"min")))
	l.add_theme_color_override("font_color", CardTheme.color(tone))
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## 毛笔字（档案页标题、钱匣数字旁的大字）。
static func brush(text: String, size: int, tone: StringName) -> Label:
	var l := label(text, size, tone)
	l.add_theme_font_override("font", CardTheme.font_title())
	return l


## 说明小字：14 号 text_2，换行。
static func note(text: String) -> Label:
	var l := label(text, 14, &"text_2", false, true)
	l.add_theme_constant_override("line_spacing", 2)
	return l


## 小节标题：15 号金色粗体（原型 .sec h3）。
static func heading(text: String) -> Label:
	return label(text, 15, &"gold_hi", true)


## 小节标题一行：金色标题 + 后面 14 号 text_3 小字（可空）。
static func heading_row(title: String, sub: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	var h := heading(title)
	h.name = "Heading"
	row.add_child(h)
	if sub != "":
		var s := label(sub, 14, &"text_3")
		s.name = "HeadingSub"
		s.size_flags_vertical = Control.SIZE_SHRINK_END
		row.add_child(s)
	return row


## 药丸：Label 自己带底（Label 的 normal 框）。
static func pill(text: String, bg: StringName = &"wood_3", edge: StringName = &"line",
		ink: StringName = &"hud_ink") -> Label:
	var l := label(text, 14, ink)
	l.add_theme_stylebox_override("normal", CardTheme.pill_style(bg, edge, 8, 6.0, 0.0))
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


## 竖排一列（不吃鼠标）。
static func column(sep: int = 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", sep)
	return v


## 横排一行（不吃鼠标）。
static func row(sep: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", sep)
	return h


## 一块带框的容器：style 为空时是透明的排版块。
static func box(style: StyleBox) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", style if style != null else StyleBoxEmpty.new())
	return p


## 竖着滚的区域：横向不滚，滚动条细条（主题给样子）。
static func scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.mouse_filter = Control.MOUSE_FILTER_PASS
	return s


## 1 像素分隔线（line 色）。
static func divider() -> ColorRect:
	var c := ColorRect.new()
	c.color = CardTheme.color(&"line")
	c.custom_minimum_size = Vector2(0, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## 头像：像素图整数倍、最近邻；外面 1px line 边（原型人物行 48x64）。没有图时只剩边框。
static func portrait(art_id: String, k: int = 1) -> PanelContainer:
	var frame := box(CardTheme.flat_style(&"wood_1", &"line", 1, 0, 0.0, 0.0))
	frame.name = "Portrait"
	var base := CardArt.base_size(art_id)
	if base == Vector2i.ZERO:
		base = Vector2i(48, 64)
	var r := TextureRect.new()
	r.texture = CardArt.texture(art_id) if art_id != "" else null
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.custom_minimum_size = Vector2(base * maxi(k, 1))
	frame.add_child(r)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return frame


## 头像上半截（脸）：48x64 的头像只取上面 crop 那块，×k 整数倍。档案簿人名格子、选择器用。
static func face(art_id: String, crop: Vector2i, k: int = 1) -> TextureRect:
	var r := TextureRect.new()
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := CardArt.texture(art_id) if art_id != "" else null
	if tex != null:
		var base := CardArt.base_size(art_id)
		if base == Vector2i.ZERO:
			base = Vector2i(tex.get_width(), tex.get_height())
		var at := AtlasTexture.new()
		at.atlas = tex
		var w := mini(crop.x, base.x)
		var h := mini(crop.y, base.y)
		at.region = Rect2(float(base.x - w) * 0.5, 0.0, w, h)
		r.texture = at
		r.custom_minimum_size = Vector2(w, h) * float(maxi(k, 1))
	else:
		r.custom_minimum_size = Vector2(crop) * float(maxi(k, 1))
	return r


## 图标（16x16 一类的小像素图）×k。
static func icon(art_id: String, k: int = 2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = CardArt.texture(art_id)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base := CardArt.base_size(art_id)
	if base == Vector2i.ZERO:
		base = Vector2i(16, 16)
	r.custom_minimum_size = Vector2(base * maxi(k, 1))
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


## 切换栏（档案簿“人物 / 规矩”、帮助“怎么玩 / 规矩”）的按钮框：on = 当前那一栏，金底深字；
## 不在的那栏木色浅字（b49：当前栏不再是灰底金字）。
static func paint_tab(b: Button, on: bool) -> void:
	if b == null:
		return
	var top := &"btn_primary_top" if on else &"btn_top"
	var bot := &"btn_primary_bot" if on else &"btn_bot"
	var edge := &"btn_primary_edge" if on else &"btn_edge"
	var normal := CardTheme.button_style(top, bot, edge, 12.0, 4.0, 5)
	var hover := CardTheme.button_style(&"btn_primary_hover_top" if on else &"btn_hover_top",
		&"btn_primary_hover_bot" if on else &"btn_top", edge if on else &"gold_deep", 12.0, 4.0, 5)
	for s in [&"normal", &"focus", &"disabled"]:
		b.add_theme_stylebox_override(s, normal)
	for s in [&"hover", &"pressed", &"hover_pressed"]:
		b.add_theme_stylebox_override(s, hover)
	var ink := CardTheme.color(&"btn_primary_ink") if on else CardTheme.color(&"hud_ink")
	var hi := CardTheme.color(&"btn_primary_ink") if on else CardTheme.color(&"gold_pale")
	for c in [&"font_color", &"font_focus_color", &"font_disabled_color"]:
		b.add_theme_color_override(c, ink)
	for c in [&"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		b.add_theme_color_override(c, hi)
	b.add_theme_font_override("font", CardTheme.font_body_bold() if on else CardTheme.font_body())
	b.add_theme_font_size_override("font_size", 15)


## 小按钮（原型 .btn.small）：主题里有 SmallButton 时用它；单独测时也给一个能看清的框。
static func small_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = &"SmallButton"
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_override("font", CardTheme.font_body())
	b.add_theme_font_size_override("font_size", 14)
	return b
