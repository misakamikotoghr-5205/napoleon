# 剧情 VN 的装饰小件（只画、不接鼠标）：底部压暗渐变、顶部压暗渐变、文本框右下角跳动的“下一句”箭头、
# 开场章节卡的横带、标题下的金线菱形饰。kind 选一种；全用抗锯齿的 draw_* 画，任何分辨率都清楚。没有 class_name。
extends Control

const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const D = preload("res://scripts/cards/ui/hd/hd_draw.gd")

## shade_bottom | shade_top | arrow | band | rule | line | dim
var kind := "rule"
## 箭头：上下跳动的相位（_process 推进）
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_process(false)


func setup(p_kind: String) -> Control:
	kind = p_kind
	set_process(kind == "arrow")
	queue_redraw()
	return self


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t = fmod(_t + delta, 1.6)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x < 2.0 or r.size.y < 2.0:
		return
	match kind:
		"shade_bottom":
			D.vgrad(self, r, [[0.0, HdTheme.alpha("hd_ink", 0.0)], [0.45, HdTheme.alpha("hd_ink", 0.38)],
				[1.0, HdTheme.alpha("hd_ink", 0.78)]])
		"shade_top":
			D.vgrad(self, r, [[0.0, HdTheme.alpha("hd_ink", 0.62)], [1.0, HdTheme.alpha("hd_ink", 0.0)]])
		"dim":
			D.vgrad(self, r, [[0.0, HdTheme.alpha("hd_ink", 0.66)], [0.5, HdTheme.alpha("hd_ink", 0.52)],
				[1.0, HdTheme.alpha("hd_ink", 0.74)]])
			D.vignette(self, r, 0.55)
		"band":
			_band(r)
		"arrow":
			_arrow(r)
		"line":
			D.fade_line(self, Vector2(0, r.size.y * 0.5), Vector2(r.size.x, r.size.y * 0.5), HdTheme.alpha("hd_gold", 0.7), 1.0)
		_:
			_rule(r)


## 章节卡的横带：中间一条深色带，上下两道渐隐金线，两头菱形
func _band(r: Rect2) -> void:
	D.vgrad(self, r, [[0.0, HdTheme.alpha("hd_ink", 0.0)], [0.22, HdTheme.alpha("hd_ink", 0.72)],
		[0.78, HdTheme.alpha("hd_ink", 0.72)], [1.0, HdTheme.alpha("hd_ink", 0.0)]])
	var y0 := r.size.y * 0.2
	var y1 := r.size.y * 0.8
	var gold := HdTheme.alpha("hd_gold", 0.85)
	D.fade_line(self, Vector2(r.size.x * 0.12, y0), Vector2(r.size.x * 0.88, y0), gold, 1.2)
	D.fade_line(self, Vector2(r.size.x * 0.12, y1), Vector2(r.size.x * 0.88, y1), gold, 1.2)
	D.diamond(self, Vector2(r.size.x * 0.5, y0), 4.5, HdTheme.color("hd_gold_hi"))
	D.diamond(self, Vector2(r.size.x * 0.5, y1), 4.5, HdTheme.color("hd_gold_hi"))


## 一道两头渐隐的金线，中间一颗菱形
func _rule(r: Rect2) -> void:
	var y := r.size.y * 0.5
	var c := HdTheme.alpha("hd_gold", 0.8)
	D.fade_line(self, Vector2(0, y), Vector2(r.size.x * 0.5 - 10.0, y), c, 1.0)
	D.fade_line(self, Vector2(r.size.x * 0.5 + 10.0, y), Vector2(r.size.x, y), c, 1.0)
	D.diamond(self, Vector2(r.size.x * 0.5, y), 3.5, HdTheme.color("hd_gold_hi"))


## “下一句”：一枚金色小三角，上下轻轻跳、明暗呼吸
func _arrow(r: Rect2) -> void:
	var k := sin(_t / 1.6 * TAU)
	var c := r.get_center() + Vector2(0, k * 3.0)
	var w := minf(r.size.x, r.size.y) * 0.36
	var glow := HdTheme.alpha("hd_gold", 0.18 + 0.12 * (k + 1.0) * 0.5)
	D.glow(self, Rect2(c - Vector2(w * 2.2, w * 2.2), Vector2(w * 4.4, w * 4.4)), glow)
	var tip := PackedVector2Array([c + Vector2(-w, -w * 0.55), c + Vector2(w, -w * 0.55), c + Vector2(0, w * 0.75)])
	D.poly(self, tip, HdTheme.alpha("hd_gold_hi", 0.75 + 0.25 * (k + 1.0) * 0.5), 1.2)
