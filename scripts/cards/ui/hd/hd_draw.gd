# 高清占位图的画图小件：竖向渐变、带抗锯齿边的多边形、发光线、径向光斑/暗角/胶片颗粒贴图、椭圆和贝塞尔取点。
# 没有 class_name；hd_ph_*.gd 和战场层可以 preload 它。颜色由调用方传（来自 hd_theme.gd 的配色键）。
extends RefCounted

const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const GRAIN_SIZE := 128

static var _radial: Texture2D = null
static var _vignette: Texture2D = null
static var _grain: Texture2D = null


## 竖向渐变：stops 是 [[0..1 的位置, Color], ...]（从上到下，至少两个）
static func vgrad(ci: CanvasItem, rect: Rect2, stops: Array) -> void:
	for i in range(stops.size() - 1):
		var a: Array = stops[i]
		var b: Array = stops[i + 1]
		var y0 := rect.position.y + rect.size.y * float(a[0])
		var y1 := rect.position.y + rect.size.y * float(b[0])
		if y1 <= y0:
			continue
		var pts := PackedVector2Array([Vector2(rect.position.x, y0), Vector2(rect.end.x, y0),
			Vector2(rect.end.x, y1), Vector2(rect.position.x, y1)])
		ci.draw_polygon(pts, PackedColorArray([a[1], a[1], b[1], b[1]]))


## 实心多边形，外圈补一道同色抗锯齿线（Godot 的多边形本身不抗锯齿）
static func poly(ci: CanvasItem, pts: PackedVector2Array, c: Color, edge: float = 1.2) -> void:
	var colors := PackedColorArray()
	colors.resize(pts.size())
	colors.fill(c)
	poly_colors(ci, pts, colors, edge)


## 每个顶点一种颜色的多边形（竖向渐变填充用），外圈同样补抗锯齿线。
## 先去掉重合的相邻点；三角化不了的（控件极小、点挤在一起）直接不画，不让引擎报错。
static func poly_colors(ci: CanvasItem, pts: PackedVector2Array, colors: PackedColorArray, edge: float = 1.2) -> void:
	var p := PackedVector2Array()
	var cs := PackedColorArray()
	for i in pts.size():
		if p.size() > 0 and pts[i].distance_squared_to(p[p.size() - 1]) < 0.0001:
			continue
		p.append(pts[i])
		cs.append(colors[mini(i, colors.size() - 1)])
	while p.size() > 3 and p[0].distance_squared_to(p[p.size() - 1]) < 0.0001:
		p.resize(p.size() - 1)
		cs.resize(cs.size() - 1)
	if p.size() < 3 or Geometry2D.triangulate_polygon(p).is_empty():
		return
	ci.draw_polygon(p, cs)
	if edge > 0.0:
		var ring := p.duplicate()
		ring.append(p[0])
		var rc := cs.duplicate()
		rc.append(cs[0])
		ci.draw_polyline_colors(ring, rc, edge, true)


## 按 y 给每个点上色：top 在 y0，bottom 在 y1
static func colors_by_y(pts: PackedVector2Array, y0: float, y1: float, top: Color, bottom: Color) -> PackedColorArray:
	var out := PackedColorArray()
	for p in pts:
		var t := clampf((p.y - y0) / maxf(y1 - y0, 1.0), 0.0, 1.0)
		out.append(top.lerp(bottom, t))
	return out


## 发光线：三道由宽到窄、由淡到浓（closed = 首尾相连）
static func glow_line(ci: CanvasItem, pts: PackedVector2Array, c: Color, width: float, closed: bool = false) -> void:
	var line := pts.duplicate()
	if closed and pts.size() > 0:
		line.append(pts[0])
	var soft := c
	soft.a = c.a * 0.10
	ci.draw_polyline(line, soft, width * 5.0, true)
	soft.a = c.a * 0.22
	ci.draw_polyline(line, soft, width * 2.4, true)
	ci.draw_polyline(line, c, width, true)


## 发光线，每个点自己一种颜色（轮廓光只亮一侧时用）
static func glow_line_colors(ci: CanvasItem, pts: PackedVector2Array, colors: PackedColorArray, width: float) -> void:
	for pass_i in [[5.0, 0.10], [2.4, 0.22], [1.0, 1.0]]:
		var cs := PackedColorArray()
		for c in colors:
			var k: Color = c
			k.a = c.a * float(pass_i[1])
			cs.append(k)
		ci.draw_polyline_colors(pts, cs, width * float(pass_i[0]), true)


## 柔和光斑：中心 c，往外渐隐；rect 可以是长方形（得到椭圆光斑）
static func glow(ci: CanvasItem, rect: Rect2, c: Color) -> void:
	ci.draw_texture_rect(radial_tex(), rect, false, c)


## 暗角：四边压暗（strength 0..1）
static func vignette(ci: CanvasItem, rect: Rect2, strength: float) -> void:
	ci.draw_texture_rect(vignette_tex(), rect, false, HdTheme.alpha("hd_ink", strength))


## 胶片颗粒（打散渐变色带）；ci 的 texture_repeat 要开
static func grain(ci: CanvasItem, rect: Rect2, strength: float) -> void:
	ci.draw_texture_rect(grain_tex(), rect, true, HdTheme.alpha("hd_white", strength))


static func ellipse(center: Vector2, rx: float, ry: float, n: int = 48, a0: float = 0.0, a1: float = TAU) -> PackedVector2Array:
	var out := PackedVector2Array()
	var full := is_equal_approx(a1 - a0, TAU)
	var count := n if full else n + 1
	for i in count:
		var a := a0 + (a1 - a0) * float(i) / float(n)
		out.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return out


## 三次贝塞尔取点（不含起点）：从 p0 经控制点 c0 c1 到 p1
static func bezier(p0: Vector2, c0: Vector2, c1: Vector2, p1: Vector2, n: int = 16) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		out.append(p0.bezier_interpolate(c0, c1, p1, t))
	return out


## 按 id 固定种子的随机数（星星、气泡的位置每次都一样）
static func rng_for(id: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	var h := 5381
	for i in id.length():
		h = ((h * 33) + id.unicode_at(i)) & 0x7fffffff
	r.seed = h
	return r


## 文字居中画在 rect 里（竖直方向按字体上下沿居中）
static func text_center(ci: CanvasItem, font: Font, text: String, center: Vector2, font_size: int, c: Color,
		shadow: Color = Color.TRANSPARENT) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var asc := font.get_ascent(font_size)
	var desc := font.get_descent(font_size)
	var base := Vector2(center.x - w * 0.5, center.y + (asc - desc) * 0.5)
	if shadow.a > 0.0:
		ci.draw_string(font, base + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, shadow)
	ci.draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, c)


## 菱形小饰（标题两侧的金线中间）
static func diamond(ci: CanvasItem, center: Vector2, r: float, c: Color) -> void:
	poly(ci, PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r),
		center + Vector2(-r, 0)]), c, 1.0)


## 一道两头渐隐的细金线（标题上下、地平线）
static func fade_line(ci: CanvasItem, a: Vector2, b: Vector2, c: Color, width: float = 1.0) -> void:
	var mid := (a + b) * 0.5
	var clear := c
	clear.a = 0.0
	ci.draw_polyline_colors(PackedVector2Array([a, mid, b]), PackedColorArray([clear, c, clear]), width, true)


static func radial_tex() -> Texture2D:
	if _radial == null:
		_radial = _radial_gradient([0.0, 0.18, 0.42, 0.7, 1.0], [1.0, 0.72, 0.34, 0.09, 0.0], "hd_white")
	return _radial


static func vignette_tex() -> Texture2D:
	if _vignette == null:
		_vignette = _radial_gradient([0.0, 0.5, 0.8, 1.0], [0.0, 0.12, 0.55, 0.9], "hd_white")
	return _vignette


static func grain_tex() -> Texture2D:
	if _grain == null:
		var r := RandomNumberGenerator.new()
		r.seed = 1815
		var bytes := PackedByteArray()
		bytes.resize(GRAIN_SIZE * GRAIN_SIZE)
		for i in bytes.size():
			bytes[i] = r.randi_range(0, 255)
		var img := Image.create_from_data(GRAIN_SIZE, GRAIN_SIZE, false, Image.FORMAT_L8, bytes)
		_grain = ImageTexture.create_from_image(img)
	return _grain


static func _radial_gradient(offsets: Array, alphas: Array, key: String) -> Texture2D:
	var g := Gradient.new()
	var cs := PackedColorArray()
	for a in alphas:
		cs.append(HdTheme.alpha(key, float(a)))
	g.offsets = PackedFloat32Array(offsets)
	g.colors = cs
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t
