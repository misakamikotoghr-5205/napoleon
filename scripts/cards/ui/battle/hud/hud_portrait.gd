## HUD 卡片上的方形头像（部署牌、情报栏、出征名单、战果的伤亡）：
##   有 art/hd/face/<id>.png → 铺满裁切；没有头像但有立绘 art/hd/chara/<id>/normal.png → 截立绘的头肩；
##   都没有 → 代码画的占位：深蓝底上一团强调色的光，立绘剪影的头肩（hd_ph_chara.gd，部队和敌人按兵种配帽子）。
## 放了图不用改代码。只画，不接鼠标；裁在自己的框里（clip_contents）。没有 class_name。
extends Control

const HdArt = preload("res://scripts/cards/ui/hd/hd_art.gd")
const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const HdPlaceholder = preload("res://scripts/cards/ui/hd/hd_placeholder.gd")
const D = preload("res://scripts/cards/ui/hd/hd_draw.gd")

## 立绘 1200×1800 里头肩那一块（画布坐标）：横向 x0..x1，从 y0 往下按控件比例取
const BUST_X0 := 230.0
const BUST_X1 := 970.0
const BUST_Y0 := 96.0
## 占位剪影按 id 配的帽子（hd_ph_chara.gd 认识的几种）
const HATS := {
	"villefort": "bicorne", "troop_line": "bicorne", "troop_grenadier": "bearskin", "troop_jager": "cap",
	"troop_hussar": "bearskin", "troop_artillery": "bicorne", "troop_medic": "cap", "troop_engineer": "cap",
	"troop_drummer": "bicorne", "enemy_whitecoat": "bicorne", "enemy_grenz": "cap", "enemy_dragoon": "bearskin",
	"enemy_hungarian": "bearskin", "enemy_leader": "bicorne", "enemy_wagon": "cap", "enemy_gun": "cap",
}

var art_id := ""
var display_name := ""
var accent: Color
## 灰掉（离场、冷却）
var dim := false:
	set(v):
		dim = v
		modulate = HdTheme.color("hd_text_3") if v else HdTheme.color("hd_white")

var _real: TextureRect = null
var _sil: Control = null


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(_fit)


func setup(id: String, p_name: String, accent_id: String = "") -> void:
	art_id = id
	display_name = p_name
	accent = HdArt.accent(accent_id if accent_id != "" else id)
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_real = null
	_sil = null
	var face := HdArt.face(id)
	if face != null:
		_real = _tex_rect(face)
	else:
		var full := HdArt.chara(id, "normal")
		if full != null:
			var at := AtlasTexture.new()
			at.atlas = full
			_real = _tex_rect(at)
		else:
			_sil = HdPlaceholder.chara_control(id, p_name, "normal")
			if "show_name" in _sil:
				_sil.set("show_name", false)
			if HATS.has(id) and "headwear" in _sil and str(_sil.get("headwear")) == "":
				_sil.set("headwear", HATS[id])
			add_child(_sil)
	set_meta(&"hd_placeholder", _real == null)
	_fit()
	queue_redraw()


func _tex_rect(t: Texture2D) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	return tr


func _fit() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	var s := size.x / (BUST_X1 - BUST_X0)
	if _real != null:
		_real.position = Vector2.ZERO
		_real.size = size
		var at := _real.texture as AtlasTexture
		if at != null and at.atlas != null:
			var k := at.atlas.get_width() / 1200.0
			at.region = Rect2(Vector2(BUST_X0, BUST_Y0) * k, Vector2(BUST_X1 - BUST_X0, size.y / s) * k)
	if _sil != null:
		_sil.size = Vector2(1200.0, 1800.0) * s
		_sil.position = -Vector2(BUST_X0, BUST_Y0) * s


func _draw() -> void:
	if _real != null or size.x < 4.0:
		return
	var r := Rect2(Vector2.ZERO, size)
	D.vgrad(self, r, [[0.0, HdTheme.color("hd_navy_2")], [1.0, HdTheme.color("hd_ink")]])
	var glow := accent
	glow.a = 0.55
	D.glow(self, Rect2(Vector2(-size.x * 0.35, -size.y * 0.45), size * Vector2(1.7, 1.5)), glow)
	var line := accent
	line.a = 0.18
	for i in range(5):
		var x := size.x * (0.15 + 0.2 * i)
		draw_line(Vector2(x, 0), Vector2(x - size.y * 0.5, size.y), line, 1.0, true)
