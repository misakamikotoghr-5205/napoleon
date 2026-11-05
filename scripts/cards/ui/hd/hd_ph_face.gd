# 头像占位（没有 art/hd/face/<id>.png 时）：一枚圆章——柔和外影、深蓝底上一团强调色的光、强调色粗圈、
# 内外两道细金圈和四个金色小菱形，中间是名字第一个字（衬线）。按方形居中，任何大小都清楚。
# 由 hd_placeholder.gd 的 face_control() 造。
extends Control

const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const D = preload("res://scripts/cards/ui/hd/hd_draw.gd")

var art_id := ""
var display_name := ""
var glyph := ""
var accent := Color.WHITE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(queue_redraw)


func setup(id: String, p_name: String, p_accent: Color) -> void:
	art_id = id
	display_name = p_name
	glyph = first_glyph(p_name if p_name != "" else id)
	accent = p_accent
	queue_redraw()


## 名字里第一个看得见的字（跳过空格和开头的括号、引号）
static func first_glyph(s: String) -> String:
	for i in s.length():
		var ch := s.substr(i, 1)
		var code := s.unicode_at(i)
		if code <= 32 or ch in ["(", "[", "\""] or (code >= 0x3000 and code <= 0x303F) or (code >= 0xFF08 and code <= 0xFF09):
			continue
		return ch.to_upper()
	return "?"


func _draw() -> void:
	var side := minf(size.x, size.y)
	if side < 6.0:
		return
	var c := size * 0.5
	var r := side * 0.5 * 0.9
	D.glow(self, Rect2(c - Vector2(r, r) * 1.25 + Vector2(0, r * 0.1), Vector2(r, r) * 2.5), HdTheme.alpha("hd_shadow", 0.7))
	draw_circle(c, r, HdTheme.color("hd_navy_2").lerp(HdTheme.color("hd_ink"), 0.35), true, -1.0, true)
	var light := accent
	light.a = 0.45
	D.glow(self, Rect2(c - Vector2(r, r) * 1.05 + Vector2(-r * 0.18, -r * 0.22), Vector2(r, r) * 2.1), light)
	var sheen := HdTheme.alpha("hd_white", 0.06)
	draw_circle(c + Vector2(0, -r * 0.45), r * 0.55, sheen, true, -1.0, true)
	draw_arc(c, r * 0.93, 0.0, TAU, 96, accent, maxf(r * 0.085, 1.5), true)
	draw_arc(c, r, 0.0, TAU, 96, HdTheme.alpha("hd_gold_hi", 0.9), maxf(r * 0.025, 1.0), true)
	draw_arc(c, r * 0.84, 0.0, TAU, 96, HdTheme.alpha("hd_gold", 0.5), maxf(r * 0.016, 1.0), true)
	for i in 4:
		var a := TAU * float(i) / 4.0 - PI * 0.5
		D.diamond(self, c + Vector2(cos(a), sin(a)) * r * 0.93, maxf(r * 0.06, 2.0), HdTheme.color("hd_gold_hi"))
	var fs := maxi(int(round(r * 0.95)), 8)
	D.text_center(self, HdTheme.font("title"), glyph, c + Vector2(0, -r * 0.02), fs, HdTheme.color("hd_text"),
		HdTheme.alpha("hd_shadow", 0.65))
