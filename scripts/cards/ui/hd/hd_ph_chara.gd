# 立绘占位（没有 art/hd/chara/<id>/<expr>.png 时）：1200:1800 的“待绘”剪影——头、颈、肩、手臂、外套翻领、
# 领巾、扣子（神甫是长袍和白领、玛丽是长裙和披肩），左上主光的渐变，右后方一道人物强调色的轮廓光
# （和美术规则的光向一致），按人物给一顶帽子（双角帽、熊皮帽、三角帽、头巾、便帽），右上角一个小表情徽记，
# 底部是名字。透明底，按比例居中、底边对齐。由 hd_placeholder.gd 的 chara_control() 造；换表情用 set_expr()。
extends Control

const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const D = preload("res://scripts/cards/ui/hd/hd_draw.gd")
const W := 1200.0
const H := 1800.0
const HEAD := Vector2(600, 345)
const HEAD_R := Vector2(128, 162)
const HEADWEAR := {
	"napoleon": "bicorne", "montholon": "bicorne", "gourgaud": "bearskin", "baptiste": "bearskin",
	"morel": "tricorne", "roberts": "tricorne", "marie": "scarf", "corso": "scarf", "oconnell": "cap",
	"pierre": "cap", "one_eyed_jack": "cap",
}
const BODY := {"marie": "dress", "faria": "robe"}

var art_id := ""
var display_name := ""
var expr := "normal"
var accent := Color.WHITE
var headwear := ""
var body_style := "coat"
## 底部的名字（剧情里有名字牌时可以关掉）
var show_name := true:
	set(v):
		show_name = v
		queue_redraw()

var _o := Vector2.ZERO   # 1200×1800 画布在控件里的左上角
var _s := 1.0            # 画布像素 -> 控件像素


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(queue_redraw)


func setup(id: String, p_name: String, p_expr: String, p_accent: Color) -> void:
	art_id = id
	display_name = p_name
	expr = p_expr
	accent = p_accent
	headwear = str(HEADWEAR.get(id, ""))
	body_style = str(BODY.get(id, "coat"))
	queue_redraw()


func set_expr(p_expr: String) -> void:
	expr = p_expr
	queue_redraw()


## 画布坐标（1200×1800）-> 控件坐标
func _p(x: float, y: float) -> Vector2:
	return _o + Vector2(x, y) * _s


func _pts(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in arr:
		out.append(_p(v.x, v.y))
	return out


## 左右对称：把左半边的画布点翻到右边（x -> 1200 - x）
func _mirror(arr: Array, side: float) -> Array:
	var out := []
	for v in arr:
		out.append(Vector2(600.0 + (v.x - 600.0) * side, v.y))
	return out


func _draw() -> void:
	var h := minf(size.y, size.x * H / W)
	if h < 8.0:
		return
	_s = h / H
	_o = Vector2((size.x - W * _s) * 0.5, size.y - h)
	D.glow(self, Rect2(_p(40, 80), Vector2(1120, 1250) * _s), _tint(0.2))
	var half := _body_half()
	var body := PackedVector2Array()
	for v in half:
		body.append(_p(v.x, v.y))
	for i in range(half.size() - 1, -1, -1):
		body.append(_p(W - half[i].x, half[i].y))
	var head := D.ellipse(_p(HEAD.x, HEAD.y), HEAD_R.x * _s, HEAD_R.y * _s, 64)
	_fill_shaded(body, _p(0, 520).y, _p(0, 1800).y, 0.2)
	_neck()
	_fill_shaded(head, _p(0, 180).y, _p(0, 500).y, 0.1)
	_hair()
	match body_style:
		"dress":
			_dress_details()
		"robe":
			_robe_details()
		_:
			_coat_details()
	_arm_seams()
	_rim_body(half)
	_rim(head, true)
	_headwear()
	_badge()
	_name_plate()


func _tint(a: float) -> Color:
	var c := accent
	c.a = a
	return c


## 身体左半边外轮廓（画布坐标，从颈根到底边）：肩、上臂、前臂、手、往里收到衣摆
func _body_half() -> PackedVector2Array:
	var sx := 300.0 if body_style == "dress" else 266.0
	var hem := sx - 50.0 if body_style == "dress" else sx + 48.0
	var pts := PackedVector2Array([Vector2(552, 535)])
	pts.append_array(D.bezier(Vector2(552, 535), Vector2(480, 568), Vector2(352, 584), Vector2(sx, 652), 14))
	pts.append_array(D.bezier(Vector2(sx, 652), Vector2(sx - 56, 694), Vector2(sx - 70, 806), Vector2(sx - 72, 965), 12))
	pts.append_array(D.bezier(Vector2(sx - 72, 965), Vector2(sx - 76, 1120), Vector2(sx - 64, 1262),
		Vector2(sx - 48, 1362), 12))
	pts.append_array(D.bezier(Vector2(sx - 48, 1362), Vector2(sx - 30, 1402), Vector2(sx + 8, 1404),
		Vector2(sx + 30, 1396), 8))
	pts.append_array(D.bezier(Vector2(sx + 30, 1396), Vector2(sx + 34, 1520), Vector2(hem, 1660), Vector2(hem, 1800), 10))
	return pts


## 竖向渐变 + 左侧主光：上亮下暗，越靠左越亮
func _fill_shaded(pts: PackedVector2Array, y0: float, y1: float, accent_mix: float) -> void:
	var top := HdTheme.color("hd_navy_3").lerp(accent, accent_mix)
	var bottom := HdTheme.color("hd_ink")
	var light := HdTheme.color("hd_parchment")
	var cs := D.colors_by_y(pts, y0, y1, top, bottom)
	var x0 := _p(180, 0).x
	var x1 := _p(1020, 0).x
	for i in pts.size():
		var xn := clampf((pts[i].x - x0) / maxf(x1 - x0, 1.0), 0.0, 1.0)
		cs[i] = cs[i].lerp(light, clampf((0.5 - xn) * 0.18, 0.0, 0.1))
	D.poly_colors(self, pts, cs, 1.2)


func _neck() -> void:
	var pts := _pts([Vector2(552, 455), Vector2(648, 455), Vector2(660, 548), Vector2(540, 548)])
	var top := HdTheme.color("hd_navy_3").lerp(accent, 0.08)
	D.poly_colors(self, pts, D.colors_by_y(pts, pts[0].y, pts[2].y, top, HdTheme.color("hd_navy")), 1.0)


func _hair() -> void:
	var pts := D.ellipse(_p(600, 326), 138.0 * _s, 150.0 * _s, 44, PI * 1.02, TAU * 0.99)
	pts.append_array(D.bezier(_p(735, 318), _p(700, 258), _p(560, 244), _p(466, 318), 10))
	D.poly(self, pts, HdTheme.color("hd_ink").lerp(accent, 0.07))


func _coat_details() -> void:
	var shirt := _pts([Vector2(556, 548), Vector2(644, 548), Vector2(600, 870)])
	D.poly(self, shirt, HdTheme.alpha("hd_parchment", 0.8))
	draw_circle(_p(600, 590), 30.0 * _s, HdTheme.color("hd_parchment"), true, -1.0, true)
	var lapel_c := HdTheme.color("hd_navy_2").lerp(accent, 0.3)
	for side in [1.0, -1.0]:
		var lapel := _pts(_mirror([Vector2(550, 540), Vector2(600, 890), Vector2(562, 942), Vector2(458, 712),
			Vector2(472, 592)], side))
		_outlined(lapel, lapel_c, _tint(0.75))
	var btn := HdTheme.color("hd_gold_hi").lerp(accent, 0.35)
	for i in 5:
		for x in [552.0, 648.0]:
			draw_circle(_p(x, 995.0 + 92.0 * float(i)), 10.0 * _s, btn, true, -1.0, true)


## 神甫：长袍、白色方领、一排小扣子
func _robe_details() -> void:
	var collar := _pts([Vector2(560, 548), Vector2(640, 548), Vector2(632, 600), Vector2(568, 600)])
	D.poly(self, collar, HdTheme.color("hd_parchment"))
	draw_line(_p(600, 600), _p(600, 1800), HdTheme.alpha("hd_ink", 0.5), maxf(3.0 * _s, 1.0), true)
	var btn := _tint(0.85)
	for i in 14:
		draw_circle(_p(600, 640.0 + 62.0 * float(i)), 7.0 * _s, btn, true, -1.0, true)


## 玛丽：交叉的白披肩（fichu）、方领口（长裙靠更宽的下摆区分）
func _dress_details() -> void:
	var neckline := _pts([Vector2(520, 560), Vector2(680, 560), Vector2(640, 700), Vector2(560, 700)])
	D.poly(self, neckline, HdTheme.color("hd_navy_3").lerp(accent, 0.12))
	var shawl := HdTheme.alpha("hd_parchment", 0.88)
	for side in [1.0, -1.0]:
		var band := _pts(_mirror([Vector2(548, 540), Vector2(470, 600), Vector2(560, 900), Vector2(640, 1010),
			Vector2(668, 960), Vector2(590, 820), Vector2(560, 660)], side))
		_outlined(band, shawl, _tint(0.6))


func _arm_seams() -> void:
	var sx := 300.0 if body_style == "dress" else 266.0
	for side in [1.0, -1.0]:
		var raw := [Vector2(sx + 78, 760), Vector2(sx + 70, 1000), Vector2(sx + 62, 1200), Vector2(sx + 58, 1360)]
		var seam := _pts(_mirror(raw, side))
		draw_polyline(seam, HdTheme.alpha("hd_ink", 0.5), maxf(4.0 * _s, 1.0), true)


func _outlined(pts: PackedVector2Array, fill: Color, edge: Color) -> void:
	D.poly(self, pts, fill)
	var ring := pts.duplicate()
	ring.append(pts[0])
	draw_polyline(ring, edge, maxf(2.0 * _s, 1.0), true)


## 身体的轮廓光：左右两条开口线（底边是裁切，不描）
func _rim_body(half: PackedVector2Array) -> void:
	for side in [1.0, -1.0]:
		var line := PackedVector2Array()
		for v in half:
			line.append(_p(600.0 + (v.x - 600.0) * side, v.y))
		_rim(line, false)


## 右后方的轮廓光：右侧亮、左侧几乎看不见
func _rim(pts: PackedVector2Array, closed: bool) -> void:
	var cx := _p(600, 0).x
	var span := 450.0 * _s
	var ring := pts.duplicate()
	if closed:
		ring.append(pts[0])
	var cs := PackedColorArray()
	for p in ring:
		var t := clampf((p.x - cx) / span, -1.0, 1.0)
		cs.append(_tint(lerpf(0.12, 0.95, smoothstep(-0.3, 0.8, t))))
	D.glow_line_colors(self, ring, cs, maxf(2.2 * _s, 1.0))


func _headwear() -> void:
	var pts := PackedVector2Array()
	match headwear:
		"bicorne":
			pts = _pts([Vector2(330, 300)])
			pts.append_array(D.bezier(_p(330, 300), _p(420, 70), _p(780, 70), _p(870, 300), 18))
			pts.append_array(D.bezier(_p(870, 300), _p(740, 238), _p(460, 238), _p(330, 300), 18).slice(0, 17))
		"bearskin":
			pts = D.ellipse(_p(600, 200), 165.0 * _s, 150.0 * _s, 44, PI, TAU)
			pts.append_array(_pts([Vector2(748, 300), Vector2(452, 300)]))
		"tricorne":
			pts = _pts([Vector2(380, 290)])
			pts.append_array(D.bezier(_p(380, 290), _p(440, 150), _p(520, 140), _p(600, 150), 10))
			pts.append_array(D.bezier(_p(600, 150), _p(680, 140), _p(760, 150), _p(820, 290), 10))
			pts.append_array(_pts([Vector2(600, 322)]))
		"scarf":
			pts = D.ellipse(_p(600, 318), 146.0 * _s, 160.0 * _s, 44, PI * 1.05, TAU * 0.975)
			pts.append_array(_pts([Vector2(742, 350), Vector2(812, 446), Vector2(772, 470), Vector2(708, 360),
				Vector2(600, 282), Vector2(462, 350)]))
		"cap":
			pts = D.ellipse(_p(600, 268), 150.0 * _s, 80.0 * _s, 36, PI, TAU)
			pts.append_array(_pts([Vector2(790, 280), Vector2(600, 296), Vector2(450, 280)]))
		_:
			return
	_outlined(pts, HdTheme.color("hd_ink").lerp(accent, 0.12), _tint(0.85))
	if headwear == "bicorne":
		draw_circle(_p(520, 215), 18.0 * _s, accent, true, -1.0, true)
		draw_circle(_p(520, 215), 8.0 * _s, HdTheme.color("hd_text"), true, -1.0, true)


## 右上角的表情徽记：普通不画；笑、怒、悲、惊各一个小符号
func _badge() -> void:
	if expr == "normal" or expr == "":
		return
	var c := _p(820, 215)
	var r := 48.0 * _s
	draw_circle(c, r, HdTheme.alpha("hd_ink", 0.9), true, -1.0, true)
	draw_arc(c, r, 0.0, TAU, 48, _tint(0.95), maxf(3.0 * _s, 1.0), true)
	var ink := HdTheme.color("hd_text")
	var w := maxf(4.0 * _s, 1.2)
	match expr:
		"smile":
			draw_arc(c + Vector2(0, -8) * _s, 20.0 * _s, deg_to_rad(20), deg_to_rad(160), 20, ink, w, true)
		"sad":
			draw_arc(c + Vector2(0, 20) * _s, 18.0 * _s, deg_to_rad(205), deg_to_rad(335), 20, ink, w, true)
			draw_circle(c + Vector2(18, -14) * _s, 6.0 * _s, HdTheme.color("hd_ally_hi"), true, -1.0, true)
		"angry":
			for sgn in [1.0, -1.0]:
				draw_line(c + Vector2(-20 * sgn, -16) * _s, c + Vector2(-4 * sgn, -6) * _s, ink, w, true)
			draw_line(c + Vector2(-14, 16) * _s, c + Vector2(14, 16) * _s, ink, w, true)
		"surprise":
			draw_line(c + Vector2(0, -22) * _s, c + Vector2(0, 6) * _s, ink, w * 1.3, true)
			draw_circle(c + Vector2(0, 20) * _s, 4.5 * _s, ink, true, -1.0, true)


func _name_plate() -> void:
	if display_name == "" or not show_name:
		return
	var fs := maxi(int(round(60.0 * _s)), 9)
	var y := _p(0, 1660).y
	var cx := _p(600, 0).x
	var half := 300.0 * _s
	D.fade_line(self, Vector2(cx - half, y - fs * 1.1), Vector2(cx + half, y - fs * 1.1), HdTheme.alpha("hd_gold", 0.8))
	D.text_center(self, HdTheme.font("title", 2), display_name, Vector2(cx, y), fs, HdTheme.color("hd_text"),
		HdTheme.alpha("hd_shadow", 0.6))
	var ids := maxi(int(round(24.0 * _s)), 8)
	D.text_center(self, HdTheme.font("sans", 3), art_id.to_upper(), Vector2(cx, y + fs * 1.0), ids,
		HdTheme.alpha("hd_gold_hi", 0.55))
