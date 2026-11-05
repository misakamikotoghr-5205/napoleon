# 战场背后的远景：有 art/hd/bg/battle_backdrop 就铺满裁切（上下各压一道暗，地图更跳），没有就自己画——
# 深蓝夜空到灰蓝薄雾的竖向渐变、三层远山剪影、硝烟带、地图后面一团暖光、暗角和胶片颗粒。全用 _draw，
# 任何分辨率都平滑。这块放在 3D 视口里（CanvasLayer -1，画在 3D 后面），所以地块边缘的抗锯齿是对着它混的。
# 颜色走配色键 bt3d_bg_*。没有 class_name。
extends Control

const HdArt = preload("res://scripts/cards/ui/hd/hd_art.gd")
const D = preload("res://scripts/cards/ui/hd/hd_draw.gd")

var glow_center := Vector2(0.5, 0.45)   # 地图中心在画面里的相对位置（暖光放在它后面）
var _tex: Texture2D = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(queue_redraw)
	_tex = HdArt.bg("battle_backdrop")
	if _tex != null:
		# 背景图导入时一般不带 mipmap，铺满时缩放不大，线性过滤就够
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func is_placeholder() -> bool:
	return _tex == null


func _c(key: String, a: float = 1.0) -> Color:
	var col := CardTheme.color(StringName(key))
	col.a *= a
	return col


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x < 2.0 or r.size.y < 2.0:
		return
	# 真图压得轻一点（只为让地图更跳），占位本来就暗
	var k := 0.6 if _tex != null else 1.0
	if _tex != null:
		_draw_cover(r)
	else:
		_draw_sky(r)
	var top := PackedVector2Array([r.position, Vector2(r.end.x, 0), Vector2(r.end.x, r.size.y * 0.22), Vector2(0, r.size.y * 0.22)])
	draw_polygon(top, PackedColorArray([_c("bt3d_bg_shade", 0.55 * k), _c("bt3d_bg_shade", 0.55 * k), _c("bt3d_bg_shade", 0.0), _c("bt3d_bg_shade", 0.0)]))
	var bot := PackedVector2Array([Vector2(0, r.size.y * 0.7), Vector2(r.end.x, r.size.y * 0.7), r.end, Vector2(0, r.end.y)])
	draw_polygon(bot, PackedColorArray([_c("bt3d_bg_shade", 0.0), _c("bt3d_bg_shade", 0.0), _c("bt3d_bg_shade", 0.7 * k), _c("bt3d_bg_shade", 0.7 * k)]))
	D.vignette(self, r, 0.55 * k)


func _draw_cover(r: Rect2) -> void:
	var ts := _tex.get_size()
	if ts.x <= 0.0 or ts.y <= 0.0:
		return
	var s := maxf(r.size.x / ts.x, r.size.y / ts.y)
	var dst := Rect2((r.size - ts * s) * 0.5, ts * s)
	draw_texture_rect(_tex, dst, false)


func _draw_sky(r: Rect2) -> void:
	var hz := 0.5
	D.vgrad(self, r, [[0.0, _c("bt3d_bg_top")], [hz, _c("bt3d_bg_mid")], [1.0, _c("bt3d_bg_bottom")]])
	var g := glow_center * r.size
	var gs := r.size.y * 0.95
	D.glow(self, Rect2(g - Vector2(gs * 1.3, gs * 0.7), Vector2(gs * 2.6, gs * 1.4)), _c("bt3d_bg_glow", 0.35))
	for layer in 3:
		_ridge(r, layer, hz)
	for band in 3:
		var y := r.size.y * (0.42 + band * 0.09)
		D.glow(self, Rect2(Vector2(-r.size.x * 0.2 + band * r.size.x * 0.3, y - r.size.y * 0.05),
			Vector2(r.size.x * 0.9, r.size.y * 0.1)), _c("bt3d_bg_smoke", 0.16))
	D.grain(self, r, 0.025)


## 一层远山：几道正弦叠出来的山脊，越近越暗越高
func _ridge(r: Rect2, layer: int, hz: float) -> void:
	var rng := D.rng_for("battle_field#ridge%d" % layer)
	var t := float(layer) / 2.0
	var base := r.size.y * (hz - 0.06 + t * 0.07)
	var amp := r.size.y * (0.07 + 0.03 * t)
	var f1 := rng.randf_range(1.6, 2.6)
	var f2 := rng.randf_range(4.0, 6.5)
	var ph := rng.randf_range(0.0, TAU)
	var pts := PackedVector2Array()
	var n := 64
	for i in n + 1:
		var u := float(i) / float(n)
		var y := base - amp * (0.55 + 0.3 * sin(u * TAU * f1 / 2.0 + ph) + 0.15 * sin(u * TAU * f2 / 2.0 + ph * 2.0))
		pts.append(Vector2(u * r.size.x, y))
	pts.append(Vector2(r.size.x, r.size.y))
	pts.append(Vector2(0, r.size.y))
	var top_c := _c("bt3d_bg_hill_far").lerp(_c("bt3d_bg_hill_near"), t)
	var bot_c := _c("bt3d_bg_bottom")
	D.poly_colors(self, pts, D.colors_by_y(pts, base - amp, r.size.y, top_c, bot_c), 1.0)
	D.glow(self, Rect2(Vector2(-r.size.x * 0.1, base - amp * 0.2), Vector2(r.size.x * 1.2, amp * 1.4)), _c("bt3d_bg_smoke", 0.12))
