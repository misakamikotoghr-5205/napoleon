# 高清美术的占位图，和“有真图用真图”的统一入口。没有 class_name，用的地方：
#   const HdPlaceholder = preload("res://scripts/cards/ui/hd/hd_placeholder.gd")
#   var bg := HdPlaceholder.make_bg("jamestown_shop", title, subtitle)      # 真图 -> TextureRect，没有 -> 章节卡
#   var who := HdPlaceholder.make_chara("marie", name, "smile")             # 真图 -> TextureRect，没有 -> 剪影
#   var face := HdPlaceholder.make_face("troop_line", name)                 # 真图 -> TextureRect，没有 -> 圆章
# 造出来的节点都不接鼠标（MOUSE_FILTER_IGNORE），线性过滤 + mipmap；meta "hd_placeholder" 是 true/false，
# "hd_id" 是 id。占位都用 _draw 画，跟着控件大小重画，任何分辨率都清楚。说明：docs/cards/HD_UI.md。
extends RefCounted

const HdArt = preload("res://scripts/cards/ui/hd/hd_art.gd")
const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const BgArt = preload("res://scripts/cards/ui/hd/hd_ph_bg.gd")
const CharaArt = preload("res://scripts/cards/ui/hd/hd_ph_chara.gd")
const FaceArt = preload("res://scripts/cards/ui/hd/hd_ph_face.gd")
const MOODS := ["night", "sea", "lamp", "interior", "dusk", "deep", "day"]
# 每个背景 / 插图的气氛（清单里的 desc 是中文，这里按 id 直接写）；变体名本身是气氛名时按变体（如 __night）
const MOOD_TABLE := {
	"bellerophon_hold": "lamp", "jamestown_shop": "interior", "royal_oak_tavern": "interior",
	"shop_back_room": "lamp", "sea_cave": "lamp", "longwood_house": "interior", "new_elba_shoal": "sea",
	"granite_palace_exchange": "interior", "granite_palace_workshop": "lamp", "skull_reef": "dusk",
	"nautilus_cabin": "deep", "vigo_seabed": "deep", "atlantis_ruins": "deep", "thames_estuary": "night",
	"camp_tent": "lamp", "battle_backdrop": "day", "title": "night",
	"ending_alliance": "deep", "ending_ghost": "night", "ending_dark": "lamp", "ending_tragedy": "dusk",
}
# 表里没有的 id 按 id 里的英文词猜
const MOOD_WORDS := [
	["night", "night"], ["seabed", "deep"], ["ruins", "deep"], ["nautilus", "deep"], ["reef", "dusk"],
	["storm", "dusk"], ["shoal", "sea"], ["beach", "sea"], ["sea", "sea"], ["cave", "lamp"], ["tent", "lamp"],
	["hold", "lamp"], ["room", "lamp"], ["shop", "interior"], ["house", "interior"], ["tavern", "interior"],
	["field", "day"], ["backdrop", "day"],
]
const TILE_NOISE := 128   # 地块占位贴图边长（无缝，平铺用）

static var _tiles: Dictionary = {}


## 背景占位（整块铺满）。mood 留空 = 按 id 查表 / 猜；可选 night sea lamp interior dusk deep day。
static func bg_control(id: String, title: String, subtitle: String = "", mood: String = "", kind: String = "bg") -> Control:
	var c := BgArt.new()
	c.setup(id, title, subtitle, mood if mood in MOODS else mood_for(id), kind)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mark(c, id, true)
	return c


## 立绘占位（1200:1800，在控件里按比例居中、底边对齐）；换表情：node.set_expr("angry")
static func chara_control(id: String, name: String, expr: String = "normal") -> Control:
	var c := CharaArt.new()
	c.setup(id, name, expr, HdArt.accent(id))
	_mark(c, id, true)
	return c


## 头像占位（圆章，按方形居中）
static func face_control(id: String, name: String) -> Control:
	var c := FaceArt.new()
	c.setup(id, name, HdArt.accent(id))
	_mark(c, id, true)
	return c


## 背景：有 art/hd/bg/<id>[__variant] 就是铺满裁切的 TextureRect，没有就是 bg_control。
## title 为空时用清单里的名字。
static func make_bg(id: String, title: String = "", subtitle: String = "", variant: String = "") -> Control:
	var tex := HdArt.bg(id, variant)
	if tex != null:
		return _tex_rect(tex, id, TextureRect.STRETCH_KEEP_ASPECT_COVERED, true)
	var t := title if title != "" else HdArt.display_name("bg", id)
	var mood := variant if variant in MOODS else ""
	return bg_control(id, t, subtitle, mood)


## 事件插图（结局 CG）：同 make_bg，找 art/hd/cg/<id>
static func make_cg(id: String, title: String = "", subtitle: String = "") -> Control:
	var tex := HdArt.cg(id)
	if tex != null:
		return _tex_rect(tex, id, TextureRect.STRETCH_KEEP_ASPECT_COVERED, true)
	var t := title if title != "" else HdArt.display_name("cg", id)
	return bg_control(id, t, subtitle, "", "cg")


## 立绘：真图是按比例居中的 TextureRect（不裁头），没有就是 chara_control。name 为空时用清单里的名字。
static func make_chara(id: String, name: String = "", expr: String = "normal") -> Control:
	var tex := HdArt.chara(id, expr)
	if tex != null:
		var tr := _tex_rect(tex, id, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, false)
		tr.set_meta(&"hd_expr", expr)
		return tr
	return chara_control(id, name if name != "" else HdArt.display_name("chara", id), expr)


## 头像：真图是按比例居中的 TextureRect，没有就是 face_control。name 为空时用清单里的名字。
static func make_face(id: String, name: String = "") -> Control:
	var tex := HdArt.face(id)
	if tex != null:
		return _tex_rect(tex, id, TextureRect.STRETCH_KEEP_ASPECT_CENTERED, false)
	return face_control(id, name if name != "" else HdArt.display_name("face", id))


## 已经造好的立绘节点换表情：真图换贴图（没有这张表情就退回 normal），占位改徽记
static func set_chara_expr(node: Control, id: String, expr: String) -> void:
	if node is TextureRect:
		var tex := HdArt.chara(id, expr)
		if tex != null:
			(node as TextureRect).texture = tex
			node.set_meta(&"hd_expr", expr)
	elif node.has_method("set_expr"):
		node.call("set_expr", expr)


## 是不是占位（不是真图）
static func is_placeholder(node: Node) -> bool:
	return node != null and bool(node.get_meta(&"hd_placeholder", false))


## 地块顶面 / 侧面贴图：有 art/hd/tile/<id>.png 用真图，没有就生成一张无缝噪声贴图（该地块的两种颜色，
## 带 mipmap，可直接给 2D 平铺或 3D 材质用）。同一个 id 只生成一次。
static func make_tile_tex(id: String) -> Texture2D:
	var real := HdArt.tile_tex(id)
	if real != null:
		return real
	return tile_texture(id)


static func tile_texture(id: String) -> Texture2D:
	if _tiles.has(id):
		return _tiles[id]
	var side := id.begins_with("side_")
	var w := TILE_NOISE
	var h := TILE_NOISE >> 1 if side else TILE_NOISE
	var broad := _noise_image(id, w, h, 0.03 if side else 0.04, 3)
	var fine := _noise_image(id + "#fine", w, h, 0.22, 2)
	var lite := HdTheme.color("hd_tile_" + id) if _has_tile_key(id) else HdTheme.color("hd_text_3")
	var dark := HdTheme.color("hd_tile_%s_dark" % id) if _has_tile_key(id) else HdTheme.color("hd_navy_3")
	for y in h:
		var strata := 0.0
		if side:
			# 侧面：上沿一条亮一点的地表，往下逐层变暗
			strata = 0.18 * (1.0 - smoothstep(0.0, 0.22, float(y) / float(h))) - 0.12 * float(y) / float(h)
		for x in w:
			var v := 0.7 * broad.get_pixel(x, y).r + 0.3 * fine.get_pixel(x, y).r
			broad.set_pixel(x, y, dark.lerp(lite, clampf(0.2 + 0.65 * smoothstep(0.1, 0.9, v) + strata, 0.0, 1.0)))
	broad.generate_mipmaps()
	var tex := ImageTexture.create_from_image(broad)
	_tiles[id] = tex
	return tex


static func _noise_image(seed_id: String, w: int, h: int, freq: float, octaves: int) -> Image:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = HdArt.accent_index(seed_id) * 97 + seed_id.length()
	noise.frequency = freq
	noise.fractal_octaves = octaves
	var img := noise.get_seamless_image(w, h)
	img.convert(Image.FORMAT_RGBA8)
	return img


## 背景 id 的气氛：查 MOOD_TABLE，再按 id 里的英文词猜，都不中就按 id 散列在 lamp / interior / night 里挑
static func mood_for(id: String) -> String:
	if MOOD_TABLE.has(id):
		return str(MOOD_TABLE[id])
	for pair in MOOD_WORDS:
		if id.contains(str(pair[0])):
			return str(pair[1])
	var pool := ["lamp", "interior", "night"]
	return pool[HdArt.accent_index(id) % pool.size()]


static func _has_tile_key(id: String) -> bool:
	return not HdArt.entry("tex", id).is_empty() or not HdArt.entry("side", id).is_empty()


static func _tex_rect(tex: Texture2D, id: String, stretch: int, full: bool) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = stretch
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if full:
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mark(tr, id, false)
	return tr


static func _mark(c: Control, id: String, placeholder: bool) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_meta(&"hd_placeholder", placeholder)
	c.set_meta(&"hd_id", id)
