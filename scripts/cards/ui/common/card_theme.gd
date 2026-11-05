# 配色、牌框样式、字体：一切颜色来自 data/cards/theme/palette.json（只有 A 写）；没有它且不是发行版时退回开发配色
# palette.dev.json（W0）。界面代码里不写颜色字面量（§11.2）。主人 C01；W0 建了能用的初版。
# 合同：docs/cards/CARDS_INTERFACES.md §1.2（配色）、§2.4（配色键）、§7.8。
# 换皮（10-22，网页原型的样子）：build_theme() 是牌桌根节点的界面主题；下面的 *_style() 是原型里反复用的几样
# （叠层面板、账簿纸、纸片、批注条、药丸、标签木牌），nine_box() 把像素九宫格整数倍放大，grad_box() 给渐变块。
class_name CardTheme
extends RefCounted

const PALETTE := "res://data/cards/theme/palette.json"
const PALETTE_DEV := "res://data/cards/theme/palette.dev.json"
const FALLBACK_KEY := "mist"   # 缺键时的替身：中性灰，深底浅底都看得见、不刺眼
const GRAD_BOX := preload("res://scripts/cards/ui/common/grad_box.gd")
const FRAME_DIALOG := "frame.dialog"   # 对话框、叠层面板的像素木框（48×48，切 7，×2）
const MODAL_PAD_H := 24.0   # 叠层面板内边距（框内），原型 .modal 20×24
const MODAL_PAD_V := 20.0

static var _colors: Dictionary = {}   # 只读缓存
static var _loaded: bool = false     # 只读一次：发行版缺 palette.json 时只报一次错
static var _bold: Font = null
static var _nine_tex: Dictionary = {}   # "art_id@k[#fill]" -> 放大好的贴图（没有图时是 null）


## 配色键（§2.4）。键不存在时开发版 push_error（测试因此变红）；两种版本都退回配色里的 mist，
## 发行版不报错、也不出洋红（§11.4 第 5 项）。配色整份没读到时退回白色。
static func color(key: StringName) -> Color:
	if not _loaded:
		_load()
	if _colors.has(str(key)):
		return _colors[str(key)]
	if not CardShip.is_ship():
		push_error("CardTheme.color: unknown palette key '%s'" % key)
	return _colors.get(FALLBACK_KEY, Color.WHITE)


## 两个配色键之间的颜色（t=0.5 是正中）：StyleBoxFlat 没有渐变时用中间色代替竖渐变。
static func mix(a: StringName, b: StringName, t: float = 0.5) -> Color:
	return color(a).lerp(color(b), t)


## 配色键换一个透明度（调透明度不算颜色字面量）。
static func with_alpha(key: StringName, a: float) -> Color:
	var c := color(key)
	c.a = a
	return c


## 牌框（没有正式牌框图时）：纸色底 + frame_<type>（金色牌用 frame_gold，边更粗）
static func frame_style(type: StringName, gold: bool) -> StyleBox:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color(&"paper")
	var key := &"frame_gold" if gold else StringName("frame_" + str(type))
	sb.border_color = color(key) if _has(key) else color(&"wood_mid")
	sb.set_border_width_all(5 if gold else 3)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	if gold:
		sb.shadow_color = color(&"gold_glow")
		sb.shadow_size = 6
	return sb


static func font_title() -> Font:
	return UiStyle.title_font()


static func font_body() -> Font:
	return UiStyle.body_font()


## 正文粗体（原型的 600/700）：正文字 + FontVariation 加粗 0.8，只建一次。
static func font_body_bold() -> Font:
	if _bold == null:
		var f := FontVariation.new()
		f.base_font = font_body()
		f.variation_embolden = 0.8
		_bold = f
	return _bold


## 字号（§1.2）：HUD 15、正文 16–18、回话 17、名字条 22、牌名 20、面板标题 28–36、最小 14。
static func font_size(role: StringName) -> int:
	match role:
		&"min":
			return 14
		&"hud":
			return 15
		&"body":
			return 16
		&"reply":
			return 17
		&"body_lg":
			return 18
		&"card":
			return 20
		&"name":
			return 22
		&"title_sm":
			return 28
		&"title":
			return 32
		&"title_lg":
			return 36
		_:
			return 16


## 纸色面板底（弹出层、分区、按钮）。颜色只读配色键。
static func panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color(&"paper")
	sb.border_color = color(&"wood_mid")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(8)
	return sb


# ---------------- 换皮：界面主题（SPEC §4.1） ----------------

## 牌桌界面主题：CardGameRoot 设一次，标题、叠层宿主、小游戏宿主都继承（CanvasLayer 下面的指引层不继承）。
## 默认正文字 16；Label 浅字 hud_ink（纸面上的 Label 自己设 ink 或用 InkLabel）；Button 木色五态；
## 变体：按钮 PrimaryButton SmallButton BigButton PrimaryBigButton WarnButton ReplyButton TabButton TabButtonR
## SkipButton；文字 InkLabel NoteLabel HintLabel ModalTitle ModalHeading PaperTitle；面板 ModalPanel PaperBook
## PaperCard RowNote。PanelContainer/Panel 默认是 modal_style()。
static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font_body()
	t.default_font_size = 16
	_theme_labels(t)
	_theme_buttons(t)
	_theme_panels(t)
	_theme_inputs(t)
	return t


static func _theme_labels(t: Theme) -> void:
	t.set_color(&"font_color", &"Label", color(&"hud_ink"))
	_label_variation(t, &"InkLabel", &"ink", 0, null)
	_label_variation(t, &"NoteLabel", &"text_2", 14, null)
	_label_variation(t, &"HintLabel", &"text_3", 14, null)
	_label_variation(t, &"ModalTitle", &"gold_hi", 30, font_title())
	_label_variation(t, &"ModalHeading", &"gold_hi", 16, font_body_bold())
	_label_variation(t, &"PaperTitle", &"seal_dark", 30, font_title())
	t.set_color(&"default_color", &"RichTextLabel", color(&"hud_ink"))
	t.set_font(&"bold_font", &"RichTextLabel", font_body_bold())
	t.set_stylebox(&"panel", &"TooltipPanel", flat_style(&"modal_bot", &"line", 1, 4, 10.0, 6.0))
	t.set_color(&"font_color", &"TooltipLabel", color(&"hud_ink"))
	t.set_font_size(&"font_size", &"TooltipLabel", 14)


static func _label_variation(t: Theme, name: StringName, key: StringName, size: int, font: Font) -> void:
	t.set_type_variation(name, &"Label")
	t.set_color(&"font_color", name, color(key))
	if size > 0:
		t.set_font_size(&"font_size", name, size)
	if font != null:
		t.set_font(&"font", name, font)


static func _theme_buttons(t: Theme) -> void:
	# 普通按钮 .btn：#4a3423→#3a281b、2px line 边、圆角 6、底影 0 2 0；悬停 #5a4028→#4a3423、边 gold_deep。
	_button_boxes(t, &"Button", [&"btn_top", &"btn_bot", &"btn_edge"], [&"btn_hover_top", &"btn_top", &"gold_deep"],
		14.0, 8.0, 6)
	_button_inks(t, &"Button", color(&"hud_ink"), color(&"gold_pale"), color(&"text_3"))
	# 主按钮 .btn.primary：金色渐变、深字粗体。
	t.set_type_variation(&"PrimaryButton", &"Button")
	_button_boxes(t, &"PrimaryButton", [&"btn_primary_top", &"btn_primary_bot", &"btn_primary_edge"],
		[&"btn_primary_hover_top", &"btn_primary_hover_bot", &"btn_primary_edge"], 14.0, 8.0, 6)
	_button_inks(t, &"PrimaryButton", color(&"btn_primary_ink"), color(&"btn_primary_ink"),
		with_alpha(&"btn_primary_ink", 0.55))
	t.set_font(&"font", &"PrimaryButton", font_body_bold())
	# 小按钮 .btn.small：内边距 4×10，字 14。
	t.set_type_variation(&"SmallButton", &"Button")
	_button_boxes(t, &"SmallButton", [&"btn_top", &"btn_bot", &"btn_edge"], [&"btn_hover_top", &"btn_top", &"gold_deep"],
		10.0, 4.0, 5)
	t.set_font_size(&"font_size", &"SmallButton", 14)
	# 大按钮 .btn.big：内边距 12×30，毛笔字 22。
	t.set_type_variation(&"BigButton", &"Button")
	_button_boxes(t, &"BigButton", [&"btn_top", &"btn_bot", &"btn_edge"], [&"btn_hover_top", &"btn_top", &"gold_deep"],
		30.0, 10.0, 6)
	t.set_font(&"font", &"BigButton", font_title())
	t.set_font_size(&"font_size", &"BigButton", 22)
	# 标题的“开张”：主按钮 + 大按钮。
	t.set_type_variation(&"PrimaryBigButton", &"PrimaryButton")
	_button_boxes(t, &"PrimaryBigButton", [&"btn_primary_top", &"btn_primary_bot", &"btn_primary_edge"],
		[&"btn_primary_hover_top", &"btn_primary_hover_bot", &"btn_primary_edge"], 30.0, 10.0, 6)
	t.set_font(&"font", &"PrimaryBigButton", font_title())
	t.set_font_size(&"font_size", &"PrimaryBigButton", 22)
	# 警告按钮 .btn.warn：印泥红渐变、白字。
	t.set_type_variation(&"WarnButton", &"Button")
	_button_boxes(t, &"WarnButton", [&"btn_warn_top", &"btn_warn_bot", &"btn_warn_edge"],
		[&"btn_warn_top", &"btn_warn_top", &"seal_rim"], 14.0, 8.0, 6)
	_button_inks(t, &"WarnButton", color(&"btn_warn_ink"), color(&"btn_warn_ink"), with_alpha(&"btn_warn_ink", 0.55))
	_theme_flat_buttons(t)


## 回话行、标签木牌、跳过：这几样不是木色按钮。
static func _theme_flat_buttons(t: Theme) -> void:
	# 回话行（§6.3）：无底，悬停/焦点 reply_hover 底、圆角 3；字 17。左对齐是 Button.alignment（属性，控件自己设）。
	t.set_type_variation(&"ReplyButton", &"Button")
	var idle := StyleBoxEmpty.new()
	idle.content_margin_left = 8.0
	idle.content_margin_right = 8.0
	idle.content_margin_top = 6.0
	idle.content_margin_bottom = 6.0
	var lit := flat_style(&"reply_hover", &"", 0, 3, 8.0, 6.0)
	for s in [&"normal", &"pressed", &"disabled"]:
		t.set_stylebox(s, &"ReplyButton", idle)
	for s in [&"hover", &"hover_pressed", &"focus"]:
		t.set_stylebox(s, &"ReplyButton", lit)
	_button_inks(t, &"ReplyButton", color(&"reply_ink"), color(&"gold_pale"), color(&"reply_off"))
	t.set_color(&"font_focus_color", &"ReplyButton", color(&"gold_pale"))
	t.set_font_size(&"font_size", &"ReplyButton", 17)
	# 两侧标签（§5.3）：左列 TabButton、右列 TabButtonR；打开时控件自己换成 tab_style(side, true)。
	for pair in [[&"TabButton", "l"], [&"TabButtonR", "r"]]:
		var name: StringName = pair[0]
		t.set_type_variation(name, &"Button")
		var off := tab_style(pair[1], false)
		var on := tab_style(pair[1], true)
		t.set_stylebox(&"normal", name, off)
		t.set_stylebox(&"disabled", name, off)
		t.set_stylebox(&"focus", name, StyleBoxEmpty.new())
		for s in [&"hover", &"pressed", &"hover_pressed"]:
			t.set_stylebox(s, name, on)
		_button_inks(t, name, color(&"hud_ink"), color(&"gold_pale"), color(&"text_3"))
		t.set_font_size(&"font_size", name, 14)
	# 对话框右上“跳过”（§6.2）：透明底、1px line 边、圆角 3、内边距 1×8，字 14 text_3；悬停字 gold_pale、边 gold_deep。
	t.set_type_variation(&"SkipButton", &"Button")
	var skip := flat_style(&"line", &"line", 1, 3, 8.0, 1.0)
	skip.draw_center = false
	var skip_hi := flat_style(&"gold_deep", &"gold_deep", 1, 3, 8.0, 1.0)
	skip_hi.draw_center = false
	for s in [&"normal", &"disabled"]:
		t.set_stylebox(s, &"SkipButton", skip)
	for s in [&"hover", &"pressed", &"hover_pressed"]:
		t.set_stylebox(s, &"SkipButton", skip_hi)
	t.set_stylebox(&"focus", &"SkipButton", StyleBoxEmpty.new())
	_button_inks(t, &"SkipButton", color(&"text_3"), color(&"gold_pale"), with_alpha(&"text_3", 0.5))
	t.set_font_size(&"font_size", &"SkipButton", 14)


## 一种按钮的五态框：normal / hover / pressed（下沉 1px、去底影）/ disabled（45%）/ focus（focus 色细圈）。
## base、hover 各是 [上, 下, 边] 三个配色键。
static func _button_boxes(t: Theme, type: StringName, base: Array, hover: Array, pad_h: float, pad_v: float,
		radius: int) -> void:
	var normal := button_style(base[0], base[1], base[2], pad_h, pad_v, radius)
	var hi := button_style(hover[0], hover[1], hover[2], pad_h, pad_v, radius)
	var pressed := hi.duplicate() as StyleBoxFlat
	pressed.shadow_size = 0
	pressed.content_margin_top = pad_v + 1.0
	pressed.content_margin_bottom = maxf(pad_v - 1.0, 0.0)
	var off := normal.duplicate() as StyleBoxFlat
	var bg := off.bg_color
	bg.a *= 0.45
	off.bg_color = bg
	var edge := off.border_color
	edge.a *= 0.45
	off.border_color = edge
	off.shadow_size = 0
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = with_alpha(&"focus", 0.7)
	focus.set_border_width_all(1)
	focus.set_corner_radius_all(radius + 2)
	focus.set_expand_margin_all(2.0)
	t.set_stylebox(&"normal", type, normal)
	t.set_stylebox(&"hover", type, hi)
	t.set_stylebox(&"pressed", type, pressed)
	t.set_stylebox(&"hover_pressed", type, pressed)
	t.set_stylebox(&"disabled", type, off)
	t.set_stylebox(&"focus", type, focus)


static func _button_inks(t: Theme, type: StringName, ink: Color, hover: Color, off: Color) -> void:
	t.set_color(&"font_color", type, ink)
	t.set_color(&"font_focus_color", type, ink)
	t.set_color(&"font_hover_color", type, hover)
	t.set_color(&"font_pressed_color", type, hover)
	t.set_color(&"font_hover_pressed_color", type, hover)
	t.set_color(&"font_disabled_color", type, off)


static func _theme_panels(t: Theme) -> void:
	t.set_stylebox(&"panel", &"PanelContainer", modal_style())
	t.set_stylebox(&"panel", &"Panel", modal_style())
	for pair in [[&"ModalPanel", modal_style()], [&"PaperBook", paper_book_style()],
			[&"PaperCard", paper_card_style()], [&"RowNote", row_note_style()]]:
		t.set_type_variation(pair[0], &"PanelContainer")
		t.set_stylebox(&"panel", pair[0], pair[1])
	var line := StyleBoxLine.new()
	line.color = color(&"line")
	line.thickness = 1
	t.set_stylebox(&"separator", &"HSeparator", line)
	var vline := StyleBoxLine.new()
	vline.color = color(&"line")
	vline.thickness = 1
	vline.vertical = true
	t.set_stylebox(&"separator", &"VSeparator", vline)


static func _theme_inputs(t: Theme) -> void:
	# 滚动条：细条，抓手 line 色、宽 6；悬停/拖着 gold_deep。
	for pair in [[&"VScrollBar", true], [&"HScrollBar", false]]:
		var type: StringName = pair[0]
		var track := _bar(with_alpha(&"btn_shadow", 0.5), pair[1])
		t.set_stylebox(&"scroll", type, track)
		t.set_stylebox(&"scroll_focus", type, track)
		t.set_stylebox(&"grabber", type, _bar(color(&"line"), pair[1]))
		t.set_stylebox(&"grabber_highlight", type, _bar(color(&"gold_deep"), pair[1]))
		t.set_stylebox(&"grabber_pressed", type, _bar(color(&"gold_deep"), pair[1]))
	# 输入框、勾选框（设置面板用）：底 btn_shadow、2px line 边、圆角 4。
	var field := flat_style(&"btn_shadow", &"line", 2, 4, 8.0, 4.0)
	var field_on := flat_style(&"btn_shadow", &"gold_deep", 2, 4, 8.0, 4.0)
	t.set_stylebox(&"normal", &"LineEdit", field)
	t.set_stylebox(&"focus", &"LineEdit", field_on)
	t.set_stylebox(&"read_only", &"LineEdit", field)
	t.set_color(&"font_color", &"LineEdit", color(&"hud_ink"))
	t.set_color(&"font_placeholder_color", &"LineEdit", color(&"text_3"))
	t.set_color(&"caret_color", &"LineEdit", color(&"gold_hi"))
	t.set_color(&"selection_color", &"LineEdit", with_alpha(&"gold_hi", 0.3))
	for s in [&"normal", &"pressed", &"disabled", &"hover_pressed"]:
		t.set_stylebox(s, &"CheckBox", field)
	t.set_stylebox(&"hover", &"CheckBox", field_on)
	t.set_stylebox(&"focus", &"CheckBox", StyleBoxEmpty.new())
	_button_inks(t, &"CheckBox", color(&"hud_ink"), color(&"gold_pale"), color(&"text_3"))
	# 滑条（音量）：槽 btn_shadow + line 边，走过的一段 gold_deep，悬停 gold_hi。
	var groove := flat_style(&"btn_shadow", &"line", 1, 3, 0.0, 3.0)
	t.set_stylebox(&"slider", &"HSlider", groove)
	t.set_stylebox(&"grabber_area", &"HSlider", flat_style(&"gold_deep", &"", 0, 3, 0.0, 3.0))
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", flat_style(&"gold_hi", &"", 0, 3, 0.0, 3.0))


static func _bar(c: Color, vertical: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(3)
	if vertical:
		sb.content_margin_left = 3.0
		sb.content_margin_right = 3.0
	else:
		sb.content_margin_top = 3.0
		sb.content_margin_bottom = 3.0
	return sb


# ---------------- 换皮：公共样子（SPEC §3.4） ----------------

## 平底框：底色键、边色键（空 = 无边）、边宽、圆角、内边距（左右, 上下）。
static func flat_style(bg: StringName, edge: StringName = &"", border: int = 0, radius: int = 0,
		pad_h: float = 0.0, pad_v: float = 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color(bg)
	if edge != &"" and border > 0:
		sb.border_color = color(edge)
		sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


## 原型 .btn 的框：上下两色取中间色、2px 边、圆角、内边距、0 2 0 的硬底影（btn_shadow）。
static func button_style(top: StringName, bot: StringName, edge: StringName, pad_h: float = 14.0,
		pad_v: float = 8.0, radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = mix(top, bot)
	sb.border_color = color(edge)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.shadow_color = color(&"btn_shadow")
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(0, 2)
	return sb


## 叠层面板 .modal：modal_top→modal_bot 的中间色铺底，外面 frame.dialog 像素木框 ×2（14px）；
## 内边距 = 框 14 + 原型 20×24。发行版没有木框图时退回平底 + 2px modal_edge 边、圆角 8。外影另垫 modal_shadow_style()。
static func modal_style() -> StyleBox:
	var sb := nine_box_filled(FRAME_DIALOG, 2, mix(&"modal_top", &"modal_bot"))
	var frame := 14.0
	sb.content_margin_left = frame + MODAL_PAD_H
	sb.content_margin_right = frame + MODAL_PAD_H
	sb.content_margin_top = frame + MODAL_PAD_V
	sb.content_margin_bottom = frame + MODAL_PAD_V
	return sb


## 叠层面板下面垫的外影（原型 0 20px 50px rgba(0,0,0,.75)）：透明底，只画影子；放在面板后面同样大小的 Panel 上。
static func modal_shadow_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT
	sb.set_corner_radius_all(8)
	sb.shadow_color = color(&"modal_shadow")
	sb.shadow_size = 40
	sb.shadow_offset = Vector2(0, 20)
	return sb


## 账簿纸 .ledgerbook（周结账、月账）：book_top→book_bot 中间色纸、3px book_edge 边、圆角 4、内边距 20×24、外影。
## 纸上的字用 ink（InkLabel），标题 PaperTitle（毛笔 30 seal_dark）。
static func paper_book_style() -> StyleBoxFlat:
	var sb := flat_style(&"book_top", &"book_edge", 3, 4, MODAL_PAD_H, MODAL_PAD_V)
	sb.bg_color = mix(&"book_top", &"book_bot")
	sb.shadow_color = color(&"modal_shadow")
	sb.shadow_size = 24
	sb.shadow_offset = Vector2(0, 10)
	return sb


## 深底抽屉里的纸片（当票、条子、黄历卡、档案页）：paper 底、圆角 4、影 0 2 6、内边距 10×8。
static func paper_card_style() -> StyleBoxFlat:
	var sb := flat_style(&"paper", &"", 0, 4, 10.0, 8.0)
	sb.shadow_color = with_alpha(&"card_shadow", 0.4)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	return sb


## 批注条 / 留着的牌那一行：左边一道竖条（默认 3px gold_deep；轮盘结果用 4px gold_hi），底是 paper 6% 透明。
static func row_note_style(edge: StringName = &"gold_deep", width: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = with_alpha(&"paper", 0.06)
	sb.border_color = color(edge)
	sb.border_width_left = width
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_right = 3
	sb.content_margin_left = 10.0 + width
	sb.content_margin_right = 10.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb


## 药丸 / 角标 / 小牌子（标签角标、HUD 在街上/在牢里、剩几天）：底色键、边色键（空 = 无边，1px）、圆角、内边距。
static func pill_style(bg: StringName, edge: StringName = &"", radius: int = 8, pad_h: float = 4.0,
		pad_v: float = 0.0) -> StyleBoxFlat:
	return flat_style(bg, edge, 1 if edge != &"" else 0, radius, pad_h, pad_v)


## 两侧标签木牌（§5.3）：side "l" 左列（贴屏幕左边，那边不画边、右两角圆 8）/ "r" 右列；on = 悬停或打开
## （btn_hover_top 底、gold_deep 边）。影 0 4 10 shade。
static func tab_style(side: String, on: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = mix(&"btn_hover_top", &"wood_2") if on else mix(&"wood_2", &"tab_bg")
	sb.border_color = color(&"gold_deep") if on else color(&"line")
	sb.set_border_width_all(2)
	if side == "r":
		sb.border_width_right = 0
		sb.corner_radius_top_left = 8
		sb.corner_radius_bottom_left = 8
	else:
		sb.border_width_left = 0
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_right = 8
	sb.shadow_color = color(&"shade")
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 2.0
	sb.content_margin_right = 2.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb


## 渐变块节点（§4.2，grad_box.gd）：上下两色键、边色键与边宽、圆角、radial = 径向（中心 0.5, 0.35）。
## 拿到后可以再调 set_colors / set_color_values / set_border / set_radius(全, 上, 下) / set_inner / set_open_sides。
static func grad_box(top: StringName, bot: StringName, edge: StringName = &"", border_px: float = 0.0,
		radius: float = 6.0, radial: bool = false) -> Control:
	var g = GRAD_BOX.new()
	g.set_colors(top, bot)
	g.set_border(border_px, edge)
	g.set_radius(radius)
	g.set_mode(GRAD_BOX.RADIAL if radial else GRAD_BOX.VERTICAL)
	return g


# ---------------- 换皮：像素九宫格放大（SPEC §4.3） ----------------

## 像素九宫格整数倍放大：CardArt 的图 ×k（最近邻，按 art_id + k 缓存），texture_margin = 清单 nine × k，四边拉伸。
## 发行版没有这张图（旧图不进包）时退回同样边距的 StyleBoxFlat（2px modal_edge 边、圆角 8），版式不变。
static func nine_box(art_id: String, k: int, draw_center: bool) -> StyleBox:
	var tex := _scaled(art_id, k, false, Color.TRANSPARENT)
	if tex == null:
		var flat := _nine_fallback(art_id, k)
		flat.draw_center = draw_center
		flat.bg_color = color(&"modal_bot")
		return flat
	return _nine_texture_box(art_id, k, tex, draw_center)


## 同 nine_box，但框里面透明的部分先铺上 fill（从中心泛洪填色，框外的角不填），一个样式就是“深底 + 木框”。
static func nine_box_filled(art_id: String, k: int, fill: Color) -> StyleBox:
	var tex := _scaled(art_id, k, true, fill)
	if tex == null:
		var flat := _nine_fallback(art_id, k)
		flat.bg_color = fill
		return flat
	return _nine_texture_box(art_id, k, tex, true)


static func _nine_texture_box(art_id: String, k: int, tex: Texture2D, draw_center: bool) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	var m := _nine_margins(art_id)
	sb.texture_margin_left = m[0] * k
	sb.texture_margin_top = m[1] * k
	sb.texture_margin_right = m[2] * k
	sb.texture_margin_bottom = m[3] * k
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sb.draw_center = draw_center
	return sb


static func _nine_fallback(art_id: String, k: int) -> StyleBoxFlat:
	var m := _nine_margins(art_id)
	var sb := StyleBoxFlat.new()
	sb.border_color = color(&"modal_edge")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = m[0] * k
	sb.content_margin_top = m[1] * k
	sb.content_margin_right = m[2] * k
	sb.content_margin_bottom = m[3] * k
	return sb


static func _nine_margins(art_id: String) -> Array:
	var m := CardArt.nine_margins(art_id)
	if m.size() < 4:
		return [0, 0, 0, 0]
	return m


static func _scaled(art_id: String, k: int, filled: bool, fill: Color) -> Texture2D:
	var key := "%s@%d" % [art_id, k]
	if filled:
		key += "#" + fill.to_html(true)
	if _nine_tex.has(key):
		return _nine_tex[key]
	var out: Texture2D = null
	var src := CardArt.texture(art_id)
	if src != null and not CardArt.is_missing(art_id):
		var img := src.get_image()
		if img != null and not img.is_empty():
			img = img.duplicate() as Image
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			if filled:
				_fill_inside(img, fill)
			img.resize(img.get_width() * maxi(k, 1), img.get_height() * maxi(k, 1), Image.INTERPOLATE_NEAREST)
			out = ImageTexture.create_from_image(img)
	_nine_tex[key] = out
	return out


## 从图中心泛洪：透明像素铺 fill（原有半透明像素叠在上面）。漏到图边（框不封口）就作废，改填九宫格中间那块。
static func _fill_inside(img: Image, fill: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var start := Vector2i(w / 2, h / 2)
	if img.get_pixelv(start).a > 0.5:
		return
	var seen := PackedByteArray()
	seen.resize(w * h)
	var hits: Array[Vector2i] = []
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var i := p.y * w + p.x
		if seen[i] == 1:
			continue
		seen[i] = 1
		if img.get_pixelv(p).a > 0.5:
			continue
		if p.x == 0 or p.y == 0 or p.x == w - 1 or p.y == h - 1:
			hits.clear()
			for y in range(h / 4, h - h / 4):
				for x in range(w / 4, w - w / 4):
					hits.append(Vector2i(x, y))
			break
		hits.append(p)
		todo.append(Vector2i(p.x + 1, p.y))
		todo.append(Vector2i(p.x - 1, p.y))
		todo.append(Vector2i(p.x, p.y + 1))
		todo.append(Vector2i(p.x, p.y - 1))
	for p in hits:
		img.set_pixelv(p, fill.blend(img.get_pixelv(p)))


static func _has(key: StringName) -> bool:
	if not _loaded:
		_load()
	return _colors.has(str(key))


static func _load() -> void:
	_loaded = true
	var path := PALETTE
	if not FileAccess.file_exists(path):
		if CardShip.is_ship():
			push_error("CardTheme: palette.json missing in ship build")
			return
		path = PALETTE_DEV
	var d = CardDB.read_json(path)
	if typeof(d) != TYPE_DICTIONARY:
		return
	# 把配色文件的十六进制串转成颜色：审核第 5 项只给这一处开了 Color.html 的例外（§11.4）。
	for k in d.get("colors", {}).keys():
		_colors[str(k)] = Color.html(str(d["colors"][k]))
