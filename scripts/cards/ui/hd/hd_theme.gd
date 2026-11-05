# 拿破仑篇高清界面的样子（“帝国蓝金”）：配色、字体、面板框、按钮、标签。没有 class_name，用的地方：
#   const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
# 颜色全部走 CardTheme.color，键是 data/cards/theme/palette.dev.json 里的 hd_*（不写颜色字面量）。
# 字体：衬线（剧情正文、标题）和无衬线（数字、界面）都先找系统里的中文字体，找不到就用仓库里的
# NotoSerifSC 子集（远洋战役用到的字它都有）。像素版旧界面不用这里的东西，这里也不改全局设置。
# 说明：docs/cards/HD_UI.md。
extends RefCounted

const HdBox = preload("res://scripts/cards/ui/hd/hd_box.gd")
const SERIF_SUBSET := "res://fonts/NotoSerifSC-Regular-subset.otf"
const SERIF_NAMES := ["Noto Serif CJK SC", "Source Han Serif SC", "Source Han Serif CN", "Noto Serif SC",
	"Songti SC", "STSong", "SimSun"]
const SANS_NAMES := ["Noto Sans CJK SC", "Source Han Sans SC", "Source Han Sans CN", "Noto Sans SC",
	"Microsoft YaHei", "PingFang SC", "Hiragino Sans GB", "WenQuanYi Micro Hei", "WenQuanYi Zen Hei", "sans-serif"]
const TITLE_SPACING := 2
# 常用字号（逻辑像素，画面按 1280×720 排版）
const SIZES := {"tiny": 12, "small": 14, "ui": 16, "body": 20, "name": 22, "num": 18, "big": 26, "title": 34,
	"hero": 52}
const BUTTON_KINDS := ["primary", "secondary", "danger", "ghost", "choice", "icon"]
const PANEL_KINDS := ["glass", "glass_strong", "glass_soft", "parchment", "textbox", "nameplate", "card",
	"card_selected", "chip", "tooltip", "hud", "slot", "header"]

# 面板框：fill / edge / inner / glow 是 [配色键, 透明度]（fill 可以写 [键, 透明度, 第二个键, 混合比]）；
# bw 边宽（bl/bb 单边覆盖）、r 圆角、inset 第二道细边内缩、sheen 上半截微光的透明度、
# shadow [透明度, 大小, 下移]、glow [配色键, 透明度, 大小]（金色外发光，代替影子）、pad [左右, 上下]。
const PANELS := {
	"glass": {"fill": ["hd_navy", 0.82], "edge": ["hd_gold", 0.55], "bw": 1, "r": 8, "inner": ["hd_gold", 0.2],
		"inset": 4, "sheen": 0.035, "shadow": [0.45, 18, 6], "pad": [18, 14]},
	"glass_strong": {"fill": ["hd_ink", 0.93], "edge": ["hd_gold", 0.8], "bw": 1, "r": 10,
		"inner": ["hd_gold", 0.28], "inset": 4, "sheen": 0.04, "shadow": [0.55, 26, 8], "pad": [24, 18]},
	"glass_soft": {"fill": ["hd_navy", 0.62], "r": 8, "shadow": [0.3, 10, 3], "pad": [14, 10]},
	"parchment": {"fill": ["hd_parchment", 1.0], "edge": ["hd_gold_deep", 0.9], "bw": 1, "r": 6,
		"inner": ["hd_gold_deep", 0.45], "inset": 4, "shadow": [0.5, 18, 6], "pad": [24, 18]},
	"textbox": {"fill": ["hd_navy", 0.94], "edge": ["hd_gold", 0.55], "bw": 1, "r": 10, "inner": ["hd_gold", 0.18],
		"inset": 5, "sheen": 0.03, "shadow": [0.5, 28, 8], "pad": [44, 26]},
	"nameplate": {"fill": ["hd_navy_2", 0.96], "edge": ["hd_gold", 0.85], "bw": 1, "bl": 4, "r": 4,
		"sheen": 0.06, "shadow": [0.45, 10, 3], "pad": [20, 6]},
	"card": {"fill": ["hd_card", 0.96], "edge": ["hd_gold", 0.35], "bw": 1, "r": 6, "sheen": 0.05,
		"shadow": [0.45, 10, 4], "pad": [8, 8]},
	"card_selected": {"fill": ["hd_card_hi", 0.98], "edge": ["hd_gold_hi", 1.0], "bw": 2, "r": 6,
		"inner": ["hd_gold_hi", 0.35], "inset": 4, "sheen": 0.07, "glow": ["hd_gold", 0.45, 14], "pad": [8, 8]},
	"chip": {"fill": ["hd_ink", 0.72], "edge": ["hd_gold", 0.45], "bw": 1, "r": 12, "pad": [10, 3]},
	"tooltip": {"fill": ["hd_ink", 0.95], "edge": ["hd_gold", 0.6], "bw": 1, "r": 6, "shadow": [0.5, 12, 4],
		"pad": [12, 8]},
	"hud": {"fill": ["hd_ink", 0.78], "edge": ["hd_gold", 0.5], "bw": 0, "bb": 1, "r": 0, "shadow": [0.35, 12, 2],
		"pad": [16, 8]},
	"slot": {"fill": ["hd_ink", 0.35], "edge": ["hd_gold", 0.28], "bw": 1, "r": 6, "pad": [8, 8]},
	"header": {"fill": ["hd_gold", 0.12], "edge": ["hd_gold", 0.6], "bw": 0, "bb": 1, "r": 0, "pad": [14, 6]},
}

# 按钮：每种五态（normal hover pressed disabled 之外 hover_pressed = pressed，focus 统一是一道金色细圈）
const BUTTONS := {
	"primary": {
		"normal": {"fill": ["hd_gold", 1.0], "edge": ["hd_gold_hi", 1.0], "bw": 1, "r": 6,
			"inner": ["hd_gold_hi", 0.55], "inset": 3, "sheen": 0.16, "shadow": [0.45, 8, 3], "pad": [30, 10]},
		"hover": {"fill": ["hd_gold", 1.0, "hd_gold_hi", 0.35], "edge": ["hd_gold_hi", 1.0], "bw": 1, "r": 6,
			"inner": ["hd_white", 0.45], "inset": 3, "sheen": 0.2, "glow": ["hd_gold_hi", 0.5, 14], "pad": [30, 10]},
		"pressed": {"fill": ["hd_gold_deep", 1.0, "hd_gold", 0.45], "edge": ["hd_gold", 1.0], "bw": 1, "r": 6,
			"inner": ["hd_gold_hi", 0.3], "inset": 3, "pad": [30, 10], "down": 1},
		"disabled": {"fill": ["hd_gold", 0.3], "edge": ["hd_gold", 0.3], "bw": 1, "r": 6, "pad": [30, 10]},
		"ink": ["hd_ink", "hd_ink", "hd_text_3"], "font": "title", "size": 22, "min": [0, 48],
	},
	"secondary": {
		"normal": {"fill": ["hd_navy_2", 0.9], "edge": ["hd_gold", 0.6], "bw": 1, "r": 6, "inner": ["hd_gold", 0.16],
			"inset": 3, "sheen": 0.05, "shadow": [0.4, 8, 3], "pad": [22, 9]},
		"hover": {"fill": ["hd_navy_3", 0.95], "edge": ["hd_gold_hi", 1.0], "bw": 1, "r": 6,
			"inner": ["hd_gold_hi", 0.25], "inset": 3, "sheen": 0.07, "glow": ["hd_gold", 0.3, 10], "pad": [22, 9]},
		"pressed": {"fill": ["hd_navy", 0.96], "edge": ["hd_gold", 0.9], "bw": 1, "r": 6, "inner": ["hd_gold", 0.2],
			"inset": 3, "pad": [22, 9], "down": 1},
		"disabled": {"fill": ["hd_navy_2", 0.5], "edge": ["hd_gold", 0.2], "bw": 1, "r": 6, "pad": [22, 9]},
		"ink": ["hd_gold_hi", "hd_text", "hd_text_3"], "font": "sans", "size": 17, "min": [0, 40],
	},
	"danger": {
		"normal": {"fill": ["hd_wax", 0.95], "edge": ["hd_wax_hi", 1.0], "bw": 1, "r": 6, "inner": ["hd_gold", 0.2],
			"inset": 3, "sheen": 0.08, "shadow": [0.4, 8, 3], "pad": [22, 9]},
		"hover": {"fill": ["hd_wax_hi", 1.0], "edge": ["hd_enemy_hi", 1.0], "bw": 1, "r": 6,
			"inner": ["hd_gold_hi", 0.3], "inset": 3, "sheen": 0.1, "glow": ["hd_enemy", 0.4, 12], "pad": [22, 9]},
		"pressed": {"fill": ["hd_wax", 1.0, "hd_ink", 0.25], "edge": ["hd_wax_hi", 1.0], "bw": 1, "r": 6,
			"pad": [22, 9], "down": 1},
		"disabled": {"fill": ["hd_wax", 0.35], "edge": ["hd_wax_hi", 0.3], "bw": 1, "r": 6, "pad": [22, 9]},
		"ink": ["hd_text", "hd_white", "hd_text_3"], "font": "sans", "size": 17, "min": [0, 40],
	},
	"ghost": {
		"normal": {"r": 6, "pad": [14, 6]},
		"hover": {"fill": ["hd_gold", 0.1], "edge": ["hd_gold", 0.35], "bw": 1, "r": 6, "pad": [14, 6]},
		"pressed": {"fill": ["hd_gold", 0.18], "edge": ["hd_gold", 0.5], "bw": 1, "r": 6, "pad": [14, 6], "down": 1},
		"disabled": {"r": 6, "pad": [14, 6]},
		"ink": ["hd_text_2", "hd_gold_hi", "hd_text_3"], "font": "sans", "size": 16, "min": [0, 32],
	},
	"choice": {
		"normal": {"fill": ["hd_navy", 0.84], "edge": ["hd_gold", 0.5], "bw": 1, "r": 6, "inner": ["hd_gold", 0.14],
			"inset": 4, "sheen": 0.04, "shadow": [0.45, 12, 4], "pad": [44, 13]},
		"hover": {"fill": ["hd_navy_3", 0.94], "edge": ["hd_gold_hi", 1.0], "bw": 1, "r": 6,
			"inner": ["hd_gold_hi", 0.3], "inset": 4, "sheen": 0.06, "glow": ["hd_gold", 0.32, 14], "pad": [44, 13]},
		"pressed": {"fill": ["hd_navy_2", 0.96], "edge": ["hd_gold", 0.9], "bw": 1, "r": 6,
			"inner": ["hd_gold", 0.2], "inset": 4, "pad": [44, 13], "down": 1},
		"disabled": {"fill": ["hd_ink", 0.88], "edge": ["hd_gold", 0.14], "bw": 1, "r": 6, "pad": [44, 13]},
		"ink": ["hd_text", "hd_gold_hi", "hd_text_3"], "font": "serif", "size": 20, "min": [520, 54],
	},
	"icon": {
		"normal": {"fill": ["hd_navy", 0.86], "edge": ["hd_gold", 0.55], "bw": 1, "r": 20, "shadow": [0.4, 6, 2],
			"pad": [8, 6]},
		"hover": {"fill": ["hd_navy_3", 0.94], "edge": ["hd_gold_hi", 1.0], "bw": 1, "r": 20,
			"glow": ["hd_gold", 0.35, 10], "pad": [8, 6]},
		"pressed": {"fill": ["hd_navy_2", 0.96], "edge": ["hd_gold", 0.9], "bw": 1, "r": 20, "pad": [8, 6], "down": 1},
		"disabled": {"fill": ["hd_navy", 0.45], "edge": ["hd_gold", 0.2], "bw": 1, "r": 20, "pad": [8, 6]},
		"ink": ["hd_gold_hi", "hd_white", "hd_text_3"], "font": "sans", "size": 18, "min": [40, 40],
	},
}

static var _fonts: Dictionary = {}
static var _subset: Font = null


# ---------------- 配色 ----------------

## 配色键 hd_*（不带 hd_ 前缀也行：color("gold") == color("hd_gold")）
static func color(key: String) -> Color:
	return CardTheme.color(StringName(_key(key)))


## 同一个键换透明度
static func alpha(key: String, a: float) -> Color:
	var c := color(key)
	c.a = c.a * a
	return c


## 两个键之间的颜色（t = 0 是 a，1 是 b）
static func mix(a: String, b: String, t: float) -> Color:
	return color(a).lerp(color(b), t)


static func size(role: String) -> int:
	return int(SIZES.get(role, 16))


# ---------------- 字体 ----------------

## "serif"（剧情正文）、"title"（标题、名字，衬线加粗、字距 +2）、"sans"（界面、数字）、"sans_bold"、"num"（粗无衬线）。
## spacing 是额外字距（像素）。同样的参数只建一次。
static func font(kind: String, spacing: int = 0) -> Font:
	var key := "%s#%d" % [kind, spacing]
	if _fonts.has(key):
		return _fonts[key]
	var f: Font
	match kind:
		"title":
			f = _spaced(_family(SERIF_NAMES, 600, true), TITLE_SPACING + spacing)
		"sans":
			f = _spaced(_family(SANS_NAMES, 400, false), spacing)
		"sans_bold", "num":
			f = _spaced(_family(SANS_NAMES, 700, false), spacing)
		_:
			f = _spaced(_family(SERIF_NAMES, 400, true), spacing)
	_fonts[key] = f
	return f


## names 里第一个系统装了的字体；衬线一个都没有时直接用仓库里的子集（有拉丁字母和全部远洋战役用字）。
static func _family(names: Array, weight: int, serif: bool) -> Font:
	var found := false
	for n in names:
		if OS.get_system_font_path(str(n)) != "":
			found = true
			break
	var fallback := _subset_font(weight)
	if not found and serif:
		return fallback
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(names)
	sf.font_weight = weight
	var fb: Array[Font] = []
	if fallback != null:
		fb.append(fallback)
	sf.fallbacks = fb
	return sf


static func _subset_font(weight: int) -> Font:
	if _subset == null and ResourceLoader.exists(SERIF_SUBSET):
		_subset = load(SERIF_SUBSET)
	if _subset == null:
		return null
	if weight < 600:
		return _subset
	var v := FontVariation.new()
	v.base_font = _subset
	v.variation_embolden = 0.55
	return v


static func _spaced(base: Font, spacing: int) -> Font:
	if spacing == 0 or base == null:
		return base
	var v := FontVariation.new()
	v.base_font = base
	v.spacing_glyph = spacing
	return v


# ---------------- 面板框 ----------------

## 面板框（每次新建，可以随便改）：glass glass_strong glass_soft parchment textbox nameplate card card_selected
## chip tooltip hud slot header。返回 StyleBoxFlat，或叠层的 hd_box.gd（.outer() 改底色和边）。
static func panel_box(kind: String) -> StyleBox:
	var spec: Dictionary = PANELS.get(kind, PANELS["glass"])
	return box(spec)


## 按规格造一个框（规格写法见文件头 PANELS 的说明）；面板和按钮都用它
static func box(spec: Dictionary) -> StyleBox:
	var outer := _flat(spec)
	var need_layers := spec.has("inner") or float(spec.get("sheen", 0.0)) > 0.0
	if not need_layers:
		return outer
	var hb := HdBox.new()
	hb.add_layer(outer)
	var r := int(spec.get("r", 0))
	var bw := float(spec.get("bw", 0))
	if float(spec.get("sheen", 0.0)) > 0.0:
		# 上半截的微光：四层由高到矮叠起来，越往上越亮，没有一道硬边
		for top in [0.52, 0.4, 0.28, 0.16]:
			var sheen := StyleBoxFlat.new()
			sheen.bg_color = alpha("hd_white", float(spec["sheen"]) * 0.25)
			sheen.corner_radius_top_left = maxi(r - 1, 0)
			sheen.corner_radius_top_right = maxi(r - 1, 0)
			sheen.corner_detail = 10
			hb.add_layer(sheen, bw, top)
	if spec.has("inner"):
		var inset := float(spec.get("inset", 4))
		var inner := StyleBoxFlat.new()
		inner.draw_center = false
		inner.border_color = _spec_color(spec["inner"])
		inner.set_border_width_all(1)
		inner.set_corner_radius_all(maxi(r - int(inset * 0.6), 1))
		inner.corner_detail = 10
		hb.add_layer(inner, inset)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		hb.set_content_margin(side, outer.get_content_margin(side))
	return hb


static func _flat(spec: Dictionary) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.anti_aliasing = true
	sb.corner_detail = 12
	if spec.has("fill"):
		sb.bg_color = _spec_color(spec["fill"])
	else:
		sb.draw_center = false
	if spec.has("edge"):
		sb.border_color = _spec_color(spec["edge"])
		sb.set_border_width_all(int(spec.get("bw", 1)))
		if spec.has("bl"):
			sb.border_width_left = int(spec["bl"])
		if spec.has("bb"):
			sb.border_width_bottom = int(spec["bb"])
	sb.set_corner_radius_all(int(spec.get("r", 0)))
	if spec.has("shadow"):
		var s: Array = spec["shadow"]
		sb.shadow_color = alpha("hd_shadow", float(s[0]))
		sb.shadow_size = int(s[1])
		sb.shadow_offset = Vector2(0, float(s[2]))
	if spec.has("glow"):
		var g: Array = spec["glow"]
		sb.shadow_color = alpha(str(g[0]), float(g[1]))
		sb.shadow_size = int(g[2])
		sb.shadow_offset = Vector2.ZERO
	var pad: Array = spec.get("pad", [0, 0])
	var down := float(spec.get("down", 0))
	sb.content_margin_left = float(pad[0])
	sb.content_margin_right = float(pad[0])
	sb.content_margin_top = float(pad[1]) + down
	sb.content_margin_bottom = maxf(float(pad[1]) - down, 0.0)
	return sb


static func _spec_color(c: Array) -> Color:
	var out := alpha(str(c[0]), float(c[1]))
	if c.size() >= 4:
		var b := color(str(c[2]))
		b.a = out.a
		out = out.lerp(b, float(c[3]))
	return out


# ---------------- 按钮、标签 ----------------

## 按钮样子：primary（金色大按钮）secondary danger ghost choice（剧情选项，宽）icon（圆角小方块）。
## 设好五态框、字体、字色，鼠标变手形；最小尺寸只会往大里改。
static func apply_button(btn: Button, kind: String) -> void:
	var spec: Dictionary = BUTTONS.get(kind, BUTTONS["secondary"])
	var normal := box(spec["normal"])
	var hover := box(spec["hover"])
	var pressed := box(spec["pressed"])
	btn.add_theme_stylebox_override(&"normal", normal)
	btn.add_theme_stylebox_override(&"hover", hover)
	btn.add_theme_stylebox_override(&"pressed", pressed)
	btn.add_theme_stylebox_override(&"hover_pressed", pressed)
	btn.add_theme_stylebox_override(&"disabled", box(spec["disabled"]))
	btn.add_theme_stylebox_override(&"focus", _focus_box(int(spec["normal"].get("r", 6))))
	var ink: Array = spec["ink"]
	var base := color(str(ink[0]))
	var hi := color(str(ink[1]))
	var off := alpha(str(ink[2]), 0.75)
	for pair in [[&"font_color", base], [&"font_focus_color", base], [&"font_hover_color", hi],
			[&"font_pressed_color", hi], [&"font_hover_pressed_color", hi], [&"font_disabled_color", off],
			[&"icon_normal_color", base], [&"icon_focus_color", base], [&"icon_hover_color", hi],
			[&"icon_pressed_color", hi], [&"icon_hover_pressed_color", hi], [&"icon_disabled_color", off]]:
		btn.add_theme_color_override(pair[0], pair[1])
	btn.add_theme_font_override(&"font", font(str(spec["font"])))
	btn.add_theme_font_size_override(&"font_size", int(spec["size"]))
	var m: Array = spec["min"]
	btn.custom_minimum_size = Vector2(maxf(btn.custom_minimum_size.x, float(m[0])),
		maxf(btn.custom_minimum_size.y, float(m[1])))
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.set_meta(&"hd_button", kind)


static func _focus_box(radius: int) -> StyleBoxFlat:
	var f := StyleBoxFlat.new()
	f.draw_center = false
	f.anti_aliasing = true
	f.border_color = alpha("hd_gold_hi", 0.75)
	f.set_border_width_all(1)
	f.set_corner_radius_all(radius + 3)
	f.set_expand_margin_all(3.0)
	return f


## 一个标签：字号、字体种类（serif title sans sans_bold num）、字色键。浅色字自动加一道淡淡的下影，压在图上也看得清。
static func make_label(text: String, font_size: int, kind: String = "sans", color_key: String = "hd_text") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", font(kind))
	l.add_theme_font_size_override(&"font_size", font_size)
	var c := color(color_key)
	l.add_theme_color_override(&"font_color", c)
	if c.get_luminance() > 0.5:
		l.add_theme_color_override(&"font_shadow_color", alpha("hd_shadow", 0.55))
		l.add_theme_constant_override(&"shadow_offset_x", 0)
		l.add_theme_constant_override(&"shadow_offset_y", 1)
		l.add_theme_constant_override(&"shadow_outline_size", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 高清面板的根节点调一次：子节点继承线性过滤 + mipmap，高清图缩小了也不糊、不闪。像素版旧界面不要调。
static func apply_hd_filter(node: CanvasItem) -> void:
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


static func _key(key: String) -> String:
	return key if key.begins_with("hd_") else "hd_" + key
