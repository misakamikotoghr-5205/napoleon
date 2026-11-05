# 背景占位（没有 art/hd/bg/<id>.jpg 时）：按地点的气氛（夜、海、灯下、室内、黄昏、深海、白天）画一张“章节卡”——
# 三段竖向渐变、光源光斑、气氛纹样（星空/海浪/船肋/窗光/风暴/光束/远山）、星盘纹饰、暗角、胶片颗粒，
# 中间偏上是地点名（大号衬线）和副标题。全用 _draw 画，任何分辨率都清楚。由 hd_placeholder.gd 的 bg_control() 造。
# 剧情开始说话后可以把地点名淡出：create_tween().tween_property(node, "title_alpha", 0.0, 0.5)。
extends Control

const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const D = preload("res://scripts/cards/ui/hd/hd_draw.gd")
# 每种气氛：地平线高度、光斑中心（相对坐标）、光斑大小（相对高度）、光斑浓度
const MOOD_LAYOUT := {
	"night": {"horizon": 0.62, "glow": Vector2(0.74, 0.22), "glow_size": 0.55, "glow_a": 0.32, "vignette": 0.62},
	"sea": {"horizon": 0.56, "glow": Vector2(0.28, 0.26), "glow_size": 0.9, "glow_a": 0.55, "vignette": 0.4},
	"lamp": {"horizon": 0.5, "glow": Vector2(0.36, 0.42), "glow_size": 1.25, "glow_a": 0.5, "vignette": 0.62},
	"interior": {"horizon": 0.52, "glow": Vector2(0.24, 0.32), "glow_size": 1.2, "glow_a": 0.42, "vignette": 0.6},
	"dusk": {"horizon": 0.6, "glow": Vector2(0.62, 0.58), "glow_size": 0.9, "glow_a": 0.55, "vignette": 0.6},
	"deep": {"horizon": 0.4, "glow": Vector2(0.5, 0.0), "glow_size": 1.3, "glow_a": 0.4, "vignette": 0.62},
	"day": {"horizon": 0.6, "glow": Vector2(0.72, 0.2), "glow_size": 0.9, "glow_a": 0.6, "vignette": 0.3},
}

var art_id := ""
var art_kind := "bg"
var title := ""
var subtitle := ""
var mood := "night"
## 地点名和副标题的透明度（0 = 不画）；可以 tween
var title_alpha := 1.0:
	set(v):
		title_alpha = clampf(v, 0.0, 1.0)
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	clip_contents = true
	resized.connect(queue_redraw)


func setup(id: String, p_title: String, p_subtitle: String, p_mood: String, kind: String = "bg") -> void:
	art_id = id
	title = p_title
	subtitle = p_subtitle
	mood = p_mood if MOOD_LAYOUT.has(p_mood) else "night"
	art_kind = kind
	queue_redraw()


func _c(part: String) -> Color:
	return HdTheme.color("hd_mood_%s_%s" % [mood, part])


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x < 2.0 or r.size.y < 2.0:
		return
	var lay: Dictionary = MOOD_LAYOUT[mood]
	var hz := float(lay["horizon"])
	D.vgrad(self, r, [[0.0, _c("top")], [hz, _c("mid")], [1.0, _c("bottom")]])
	var g: Vector2 = lay["glow"]
	var gs := float(lay["glow_size"]) * r.size.y
	var gc := _c("glow")
	gc.a = float(lay["glow_a"])
	D.glow(self, Rect2(Vector2(g.x * r.size.x, g.y * r.size.y) - Vector2(gs, gs * 0.8), Vector2(gs * 2.0, gs * 1.6)), gc)
	match mood:
		"night":
			_stars(r, hz)
			_skyline(r, hz)
			_reflection(r, hz)
		"sea":
			_waves(r, hz, 0.22)
			_island(r, hz)
		"lamp":
			_ribs(r)
			_floor(r, hz)
		"interior":
			_window(r)
			_floor(r, hz)
		"dusk":
			_clouds(r)
			_waves(r, hz, 0.14)
			_reef(r, hz)
		"deep":
			_rays(r)
			_bubbles(r)
			_seabed(r)
		"day":
			_mountains(r, hz)
	_astrolabe(r)
	D.vignette(self, r, float(lay["vignette"]))
	D.grain(self, r, 0.03)
	if title_alpha > 0.0:
		_title_block(r)
	if show_art_ids():
		_catalogue(r)


## 右上角的 BG <ID> 小字只给美术对号用：默认不画；项目设置 dehoudang/hd/show_art_ids = true
## 或环境变量 DEHOUDANG_SHOW_ART_IDS=1 时才画。
static func show_art_ids() -> bool:
	if OS.get_environment("DEHOUDANG_SHOW_ART_IDS") in ["1", "true", "yes"]:
		return true
	return bool(ProjectSettings.get_setting("dehoudang/hd/show_art_ids", false))


# ---------------- 气氛纹样 ----------------

func _stars(r: Rect2, hz: float) -> void:
	var rng := D.rng_for(art_id + "#stars")
	var k := r.size.y / 720.0
	var c := _c("line")
	for i in 90:
		var p := Vector2(rng.randf() * r.size.x, pow(rng.randf(), 1.4) * r.size.y * hz * 0.92)
		c.a = rng.randf_range(0.12, 0.7)
		draw_circle(p, rng.randf_range(0.5, 1.7) * k, c, true, -1.0, true)
	_moon(MOOD_LAYOUT["night"]["glow"] * r.size, 26.0 * k)


## 月牙：两个等大圆的差（亮的一面朝左下），不靠“压一块深色圆”，背后天色怎样都不露馅
func _moon(center: Vector2, rad: float) -> void:
	var halo := _c("line")
	halo.a = 0.22
	D.glow(self, Rect2(center - Vector2(rad, rad) * 3.0, Vector2(rad, rad) * 6.0), halo)
	var u := Vector2(0.8, -0.6)
	var d := rad * 0.62
	var phi := u.angle()
	var th := acos(clampf(d / (2.0 * rad), -1.0, 1.0))
	var pts := D.ellipse(center, rad, rad, 40, phi + th, phi + TAU - th)
	var back := D.ellipse(center + u * d, rad, rad, 24, phi + PI + th, phi + PI - th)
	pts.append_array(back.slice(1, back.size() - 1))   # 两头和外弧的端点重合，去掉免得三角化失败
	var mc := _c("line")
	mc.a = 0.85
	D.poly(self, pts, mc)


func _skyline(r: Rect2, hz: float) -> void:
	var y := r.size.y * hz
	var pts := PackedVector2Array([Vector2(0, y + 18)])
	var rng := D.rng_for(art_id + "#coast")
	var x := 0.0
	while x < r.size.x:
		x += r.size.x * rng.randf_range(0.04, 0.09)
		pts.append(Vector2(minf(x, r.size.x), y - rng.randf_range(0.0, 0.06) * r.size.y))
	pts.append(Vector2(r.size.x, r.size.y))
	pts.append(Vector2(0, r.size.y))
	D.poly_colors(self, pts, D.colors_by_y(pts, y - 0.06 * r.size.y, r.size.y, _c("bottom").lerp(_c("mid"), 0.25),
		_c("bottom")), 0.0)
	var lc := _c("glow")
	lc.a = 0.35
	D.fade_line(self, Vector2(0, y), Vector2(r.size.x, y), lc, 1.0)


## 夜里水面上的月光倒影：月亮正下方一列由近及远变短的横线
func _reflection(r: Rect2, hz: float) -> void:
	var x: float = MOOD_LAYOUT["night"]["glow"].x * r.size.x
	var y0 := r.size.y * hz + 6.0
	var c := _c("line")
	var rng := D.rng_for(art_id + "#glint")
	for i in 16:
		var t := float(i) / 15.0
		var y := y0 + (r.size.y - y0) * pow(t, 1.3) * 0.9
		var w := r.size.x * (0.012 + 0.05 * t) * rng.randf_range(0.6, 1.2)
		c.a = 0.28 * (1.0 - t * 0.6)
		var dx := rng.randf_range(-0.01, 0.01) * r.size.x
		D.fade_line(self, Vector2(x + dx - w, y), Vector2(x + dx + w, y), c, 1.0 + t)
	var wc := _c("line")
	for i in 5:
		var t := float(i + 1) / 6.0
		var y := y0 + (r.size.y - y0) * t
		wc.a = 0.035 + 0.03 * t
		D.fade_line(self, Vector2(0, y), Vector2(r.size.x, y), wc, 1.0)


func _waves(r: Rect2, hz: float, strength: float) -> void:
	var y0 := r.size.y * hz
	var c := _c("line")
	for i in 9:
		var t := float(i) / 8.0
		var y := y0 + (r.size.y - y0) * pow(t, 1.6) * 0.95 + 4.0
		var amp := 1.5 + 9.0 * t
		var pts := PackedVector2Array()
		var n := 48
		for j in n + 1:
			var x := r.size.x * float(j) / float(n)
			pts.append(Vector2(x, y + sin(x * (0.012 - 0.006 * t) + float(i) * 1.7) * amp))
		c.a = strength * (0.35 + 0.65 * t)
		draw_polyline(pts, c, 1.0 + 1.2 * t, true)
	var hc := _c("glow")
	hc.a = 0.6
	D.fade_line(self, Vector2(0, y0), Vector2(r.size.x, y0), hc, 1.2)


func _island(r: Rect2, hz: float) -> void:
	var y := r.size.y * hz
	var cx := r.size.x * 0.78
	var w := r.size.x * 0.16
	var h := r.size.y * 0.07
	var pts := PackedVector2Array([Vector2(cx - w, y), Vector2(cx - w * 0.35, y - h * 0.55),
		Vector2(cx - w * 0.12, y - h), Vector2(cx + w * 0.08, y - h * 0.95), Vector2(cx + w * 0.4, y - h * 0.45),
		Vector2(cx + w, y)])
	var c := _c("top").lerp(_c("bottom"), 0.5)
	c.a = 0.55
	D.poly(self, pts, c)


func _ribs(r: Rect2) -> void:
	var c := _c("line")
	for i in 6:
		var t := float(i) / 5.0
		var cx := r.size.x * 0.5
		var rx := r.size.x * (0.32 + 0.5 * t)
		var ry := r.size.y * (0.52 + 0.5 * t)
		c.a = 0.05 + 0.05 * t
		var pts := D.ellipse(Vector2(cx, r.size.y * 0.98), rx, ry, 64, PI, TAU)
		draw_polyline(pts, c, 2.0 + 5.0 * t, true)
	var lamp: Vector2 = MOOD_LAYOUT["lamp"]["glow"] * r.size
	var core := _c("glow")
	core.a = 0.85
	D.glow(self, Rect2(lamp - Vector2(34, 34), Vector2(68, 68)), core)


func _floor(r: Rect2, hz: float) -> void:
	var vp := Vector2(r.size.x * 0.5, r.size.y * hz)
	var c := _c("line")
	c.a = 0.05
	for i in 13:
		var x := r.size.x * (-0.6 + 2.2 * float(i) / 12.0)
		draw_line(vp, Vector2(x, r.size.y), c, 1.0, true)
	for i in 6:
		var t := pow(float(i + 1) / 6.0, 2.0)
		var y := vp.y + (r.size.y - vp.y) * t
		c.a = 0.03 + 0.04 * t
		draw_line(Vector2(0, y), Vector2(r.size.x, y), c, 1.0, true)


func _window(r: Rect2) -> void:
	var w := Rect2(r.size.x * 0.12, r.size.y * 0.14, r.size.x * 0.17, r.size.y * 0.36)
	var light := _c("glow")
	light.a = 0.09
	var shaft := PackedVector2Array([w.position, Vector2(w.end.x, w.position.y),
		Vector2(w.end.x + r.size.x * 0.32, r.size.y), Vector2(w.position.x + r.size.x * 0.16, r.size.y)])
	D.poly(self, shaft, light, 0.0)
	var pane := _c("glow")
	pane.a = 0.16
	draw_rect(w, pane, true)
	var frame := _c("line")
	frame.a = 0.32
	draw_rect(w, frame, false, 2.0, true)
	draw_line(Vector2(w.get_center().x, w.position.y), Vector2(w.get_center().x, w.end.y), frame, 2.0, true)
	draw_line(Vector2(w.position.x, w.position.y + w.size.y * 0.45), Vector2(w.end.x, w.position.y + w.size.y * 0.45),
		frame, 2.0, true)


func _clouds(r: Rect2) -> void:
	var rng := D.rng_for(art_id + "#clouds")
	var c := _c("top")
	for i in 7:
		c.a = rng.randf_range(0.35, 0.6)
		var cw := r.size.x * rng.randf_range(0.35, 0.7)
		var ch := r.size.y * rng.randf_range(0.08, 0.16)
		var p := Vector2(rng.randf_range(-0.2, 0.9) * r.size.x, rng.randf_range(0.04, 0.42) * r.size.y)
		D.glow(self, Rect2(p, Vector2(cw, ch)), c)
	var streak := _c("glow")
	streak.a = 0.18
	for i in 4:
		var y := r.size.y * (0.38 + 0.05 * float(i))
		D.fade_line(self, Vector2(r.size.x * 0.25, y), Vector2(r.size.x * 0.98, y + 6.0), streak, 1.5)


## 礁石：一串高低不一的尖峰，两头收进海面
func _reef(r: Rect2, hz: float) -> void:
	var y := r.size.y * hz + 2.0
	var rng := D.rng_for(art_id + "#reef")
	var x0 := r.size.x * 0.04
	var x1 := r.size.x * 0.42
	var pts := PackedVector2Array([Vector2(x0, y)])
	var n := 14
	for i in range(1, n):
		var t := float(i) / float(n)
		var env := sin(t * PI)
		var peak := (0.03 + 0.11 * env) * r.size.y * (rng.randf_range(0.45, 1.0) if i % 2 == 0 else rng.randf_range(0.15, 0.5))
		pts.append(Vector2(lerpf(x0, x1, t) + rng.randf_range(-0.006, 0.006) * r.size.x, y - peak))
	pts.append(Vector2(x1, y))
	D.poly(self, pts, _c("bottom"))
	var lit := _c("glow")
	lit.a = 0.35
	var edge := PackedVector2Array()
	for i in range(pts.size() >> 1, pts.size()):
		edge.append(pts[i])
	draw_polyline(edge, lit, 1.2, true)


func _rays(r: Rect2) -> void:
	var rng := D.rng_for(art_id + "#rays")
	var top := _c("glow")
	var clear := top
	clear.a = 0.0
	for i in 6:
		var x := r.size.x * rng.randf_range(0.15, 0.85)
		var w0 := r.size.x * rng.randf_range(0.02, 0.05)
		var w1 := w0 * 4.0
		var lean := r.size.x * rng.randf_range(-0.08, 0.08)
		top.a = rng.randf_range(0.06, 0.13)
		var pts := PackedVector2Array([Vector2(x - w0, 0), Vector2(x + w0, 0),
			Vector2(x + lean + w1, r.size.y * 0.85), Vector2(x + lean - w1, r.size.y * 0.85)])
		D.poly_colors(self, pts, PackedColorArray([top, top, clear, clear]), 0.0)


func _bubbles(r: Rect2) -> void:
	var rng := D.rng_for(art_id + "#bubbles")
	var k := r.size.y / 720.0
	var c := _c("line")
	for i in 34:
		c.a = rng.randf_range(0.12, 0.4)
		var p := Vector2(rng.randf() * r.size.x, rng.randf_range(0.15, 0.95) * r.size.y)
		draw_arc(p, rng.randf_range(1.5, 6.0) * k, 0.0, TAU, 20, c, 1.0, true)


func _seabed(r: Rect2) -> void:
	var pts := PackedVector2Array([Vector2(0, r.size.y * 0.84)])
	var n := 24
	for i in n + 1:
		var x := r.size.x * float(i) / float(n)
		pts.append(Vector2(x, r.size.y * (0.84 + 0.035 * sin(float(i) * 0.9) + 0.02 * sin(float(i) * 2.3))))
	pts.append(Vector2(r.size.x, r.size.y))
	pts.append(Vector2(0, r.size.y))
	var c := _c("bottom")
	c.a = 0.85
	D.poly(self, pts, c, 0.0)


func _mountains(r: Rect2, hz: float) -> void:
	var y := r.size.y * hz
	for layer in 3:
		var rng := D.rng_for(art_id + "#mtn%d" % layer)
		var t := float(layer) / 2.0
		var pts := PackedVector2Array([Vector2(0, r.size.y)])
		var peak := r.size.y * (0.16 - 0.05 * t)
		var f1 := rng.randf_range(2.0, 3.5)
		var f2 := rng.randf_range(5.0, 8.0)
		var ph := rng.randf_range(0.0, TAU)
		var n := 72
		for i in n + 1:
			var u := float(i) / float(n)
			var ridge := 0.55 + 0.3 * sin(u * TAU * f1 * 0.5 + ph) + 0.15 * sin(u * TAU * f2 * 0.5 + ph * 2.0)
			ridge += 0.06 * sin(u * TAU * 11.0 + ph * 3.0)
			pts.append(Vector2(r.size.x * u, y - ridge * peak + r.size.y * 0.05 * t))
		pts.append(Vector2(r.size.x, r.size.y))
		var c := _c("mid").lerp(_c("bottom"), 0.35 + 0.3 * t)
		D.poly(self, pts, c, 0.0)
	var haze := _c("glow")
	haze.a = 0.25
	D.glow(self, Rect2(-r.size.x * 0.2, y - r.size.y * 0.12, r.size.x * 1.4, r.size.y * 0.24), haze)


# ---------------- 纹饰与文字 ----------------

func _astrolabe(r: Rect2) -> void:
	var c := HdTheme.alpha("hd_gold", 0.075)
	var center := Vector2(r.size.x * 0.5, r.size.y * 0.42)
	var rad := r.size.y * 0.33
	for k in [1.0, 0.93, 0.62]:
		draw_arc(center, rad * k, 0.0, TAU, 128, c, 1.2, true)
	for i in 72:
		var a := TAU * float(i) / 72.0
		var inner := rad * (0.86 if i % 6 == 0 else 0.9)
		var dir := Vector2(cos(a), sin(a))
		draw_line(center + dir * inner, center + dir * rad * 0.93, c, 1.0, true)
	for i in 4:
		var a := TAU * float(i) / 4.0
		D.diamond(self, center + Vector2(cos(a), sin(a)) * rad, 5.0, HdTheme.alpha("hd_gold", 0.16))


func _title_block(r: Rect2) -> void:
	var k := r.size.y / 720.0
	var a := title_alpha
	var ts := clampi(int(round(54.0 * k)), 18, 120)
	var ss := clampi(int(round(19.0 * k)), 10, 44)
	var cy := r.size.y * 0.42
	var half := r.size.x * 0.17
	var cx := r.size.x * 0.5
	var top_y := cy - float(ts) * 0.95
	D.fade_line(self, Vector2(cx - half, top_y), Vector2(cx + half, top_y), HdTheme.alpha("hd_gold", 0.85 * a), 1.0)
	D.diamond(self, Vector2(cx, top_y), 4.0 * k, HdTheme.alpha("hd_gold_hi", a))
	if title != "":
		D.text_center(self, HdTheme.font("title", 4), title, Vector2(cx, cy), ts, HdTheme.alpha("hd_text", a),
			HdTheme.alpha("hd_shadow", 0.6 * a))
	var sub_y := cy + float(ts) * 0.82
	if subtitle != "":
		D.text_center(self, HdTheme.font("sans", 3), subtitle, Vector2(cx, sub_y), ss, HdTheme.alpha("hd_gold_hi", a),
			HdTheme.alpha("hd_shadow", 0.5 * a))
	var low_y := sub_y + float(ss) * 1.2
	D.fade_line(self, Vector2(cx - half * 0.6, low_y), Vector2(cx + half * 0.6, low_y),
		HdTheme.alpha("hd_gold", 0.5 * a), 1.0)


func _catalogue(r: Rect2) -> void:
	if art_id == "":
		return
	var k := r.size.y / 720.0
	var fs := clampi(int(round(11.0 * k)), 9, 26)
	var f := HdTheme.font("sans", 3)
	var text := "%s  %s" % [art_kind.to_upper(), art_id.to_upper()]
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(r.size.x - w - 22.0 * k, 26.0 * k)
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, HdTheme.alpha("hd_gold_hi", 0.42))
	D.fade_line(self, pos + Vector2(-8.0 * k, 8.0 * k), pos + Vector2(w + 8.0 * k, 8.0 * k), HdTheme.alpha("hd_gold", 0.3))
